@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_InputSystem

## Phase 16+: Dispatches keyboard/mouse/gamepad input to store and components.
## Delegates device-specific input capture to IInputSource implementations.

const INPUT_TYPE := StringName("C_InputComponent")
const GAMEPAD_TYPE := StringName("C_GamepadComponent")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/core/ecs/components/c_player_tag_component.gd")
const PLAYER_TAG_TYPE := C_PLAYER_TAG_COMPONENT.COMPONENT_TYPE
const ACTION_MOVE_STRENGTH := StringName("move")
const ACTION_LOOK_STRENGTH := StringName("look")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/core/ecs/components/c_character_state_component.gd")
const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/core/utils/debug/u_debug_log_throttle.gd")

# Use centralized DeviceType enum
const DeviceType := U_DeviceTypeConstants.DeviceType

@export var negative_x_action: StringName = StringName("move_left")
@export var positive_x_action: StringName = StringName("move_right")
@export var negative_z_action: StringName = StringName("move_forward")
@export var positive_z_action: StringName = StringName("move_backward")
@export var look_left_action: StringName = StringName("look_left")
@export var look_right_action: StringName = StringName("look_right")
@export var look_up_action: StringName = StringName("look_up")
@export var look_down_action: StringName = StringName("look_down")
@export var camera_center_action: StringName = StringName("camera_center")
@export var jump_action: StringName = StringName("jump")
@export var sprint_action: StringName = StringName("sprint")
@export var interact_action: StringName = StringName("interact")
@export var input_deadzone: float = 0.15
@export var require_captured_cursor: bool = false
@export var debug_input_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null

var _actions_validated := false
var _actions_valid: bool = true
var _state_store: I_StateStore = null
var _store_unsubscribe: Callable = Callable()
var _input_device_manager: M_InputDeviceManager = null
var _gamepad_settings_cache: Dictionary = {}
var _sprint_toggle_enabled: bool = false
var _sprint_toggled_on: bool = false
var _sprint_button_was_pressed: bool = false
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.INPUT

func on_configured() -> void:
	_validate_required_actions()
	_ensure_state_store_ready()
	_ensure_input_device_manager()
	# Device connection/hotplug is handled by M_InputDeviceManager.
	# Input event capture is delegated to IInputSource implementations.

func _ensure_input_device_manager() -> void:
	if _input_device_manager != null and is_instance_valid(_input_device_manager):
		return
	# Get input device manager via ServiceLocator (Phase 10B-7: T141c)
	# Use try_get_service to avoid errors in test environments
	_input_device_manager = U_ServiceLocator.try_get_service(StringName("input_device_manager")) as M_InputDeviceManager

func process_tick(_delta: float) -> void:
	_debug_log_throttle.tick(_delta)
	_validate_required_actions()
	if not _actions_valid:
		_debug_log_input("blocked: required input actions are invalid")
		return
	_ensure_state_store_ready()
	_ensure_input_device_manager()

	var store := _get_state_store()
	var state: Dictionary = {}
	var active_device_type: int = DeviceType.KEYBOARD_MOUSE
	var active_gamepad_id: int = -1
	var is_gamepad_connected: bool = false

	if store:
		state = store.get_state()
		active_device_type = U_InputSelectors.get_active_device_type(state)
		active_gamepad_id = U_InputSelectors.get_active_gamepad_id(state)
		is_gamepad_connected = U_InputSelectors.is_gamepad_connected(state)
		_update_accessibility_from_state(state)

	# Only gate input on cursor capture for desktop platforms.
	if not OS.has_feature("mobile"):
		if require_captured_cursor and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_debug_log_input(
				"blocked: require_captured_cursor=true mouse_mode=%s" % _mouse_mode_to_string(Input.mouse_mode)
			)
			return

	if not _is_gameplay_active_for_inputs():
		_debug_log_input("blocked: gameplay input gate is inactive")
		return

	if active_device_type == DeviceType.TOUCHSCREEN:
		var touch_look_active := U_GameplaySelectors.is_touch_look_active(state)
		if touch_look_active:
			_debug_log_input("blocked: touchscreen drag-look active; S_TouchscreenSystem owns input dispatch")
		else:
			_debug_log_input("blocked: touchscreen active device; S_TouchscreenSystem owns input dispatch")
		return

	# Get active input source and delegate input capture
	var input_source: I_InputSource = null
	if _input_device_manager:
		input_source = _input_device_manager.get_input_source_for_device(active_device_type)

	if input_source == null:
		_debug_log_input(
			"blocked: no input source for active_device=%s"
			% _device_type_to_string(active_device_type)
		)
		return

	# Capture input from active source
	var input_data := input_source.capture_input(_delta)
	var final_movement: Vector2 = input_data.get("move_input", Vector2.ZERO)
	var look_delta: Vector2 = input_data.get("look_input", Vector2.ZERO)
	var camera_center_just_pressed: bool = bool(input_data.get("camera_center_just_pressed", false))
	var jump_pressed: bool = input_data.get("jump_pressed", false)
	var jump_just_pressed: bool = input_data.get("jump_just_pressed", false)
	var sprint_button_pressed: bool = input_data.get("sprint_pressed", false)
	_debug_log_capture_snapshot(state, active_device_type, input_source, look_delta)

	# Apply sprint toggle if enabled
	var sprint_pressed := _compute_sprint_pressed(sprint_button_pressed)

	# Dispatch input to state store (batched: 1 dispatch instead of 5)
	if store:
		var look_source := U_InputActions.LOOK_SOURCE_KEYBOARD_MOUSE
		if active_device_type == DeviceType.GAMEPAD:
			look_source = U_InputActions.LOOK_SOURCE_GAMEPAD
		store.dispatch(U_InputActions.update_input_batch(
			final_movement,
			look_delta,
			look_source,
			camera_center_just_pressed,
			jump_pressed,
			jump_just_pressed,
			sprint_pressed
		))

	var move_strength := clampf(final_movement.length(), 0.0, 1.0)
	var look_strength := clampf(look_delta.length(), 0.0, 1.0)

	# Write to components (other systems read from them)
	var entities: Array = query_entities([INPUT_TYPE, PLAYER_TAG_TYPE], [GAMEPAD_TYPE])
	for entity_query in entities:
		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if input_component == null:
			continue

		input_component.set_move_vector(final_movement)
		input_component.set_sprint_pressed(sprint_pressed)
		if jump_just_pressed:
			input_component.set_jump_pressed(true)
		input_component.set_device_type(active_device_type)
		input_component.clear_action_strengths()
		input_component.set_action_strength(ACTION_MOVE_STRENGTH, move_strength)
		input_component.set_action_strength(ACTION_LOOK_STRENGTH, look_strength)

		var gamepad_component: C_GamepadComponent = entity_query.get_component(GAMEPAD_TYPE)
		if gamepad_component != null:
			# Get gamepad-specific data from source
			var gamepad_source := input_source as GamepadSource
			if gamepad_source:
				gamepad_component.left_stick = final_movement
				gamepad_component.right_stick = look_delta
				gamepad_component.button_states = gamepad_source.get_button_states()
			gamepad_component.connected = is_gamepad_connected
			gamepad_component.device_id = active_gamepad_id
			gamepad_component.apply_settings_from_dictionary(_gamepad_settings_cache)

func _update_accessibility_from_state(state: Dictionary) -> void:
	var accessibility: Dictionary = U_SettingsSelectors.get_accessibility_settings(state)
	_sprint_toggle_enabled = bool(accessibility.get("sprint_toggle_mode", false))

func _compute_sprint_pressed(button_pressed: bool) -> bool:
	if not _sprint_toggle_enabled:
		_sprint_toggled_on = false
		_sprint_button_was_pressed = button_pressed
		return button_pressed

	var just_pressed := button_pressed and not _sprint_button_was_pressed
	if just_pressed:
		_sprint_toggled_on = not _sprint_toggled_on
	_sprint_button_was_pressed = button_pressed
	return _sprint_toggled_on

func _validate_required_actions() -> void:
	if _actions_validated:
		return
	_actions_validated = true

	var required_actions: Array[StringName] = [
		negative_x_action,
		positive_x_action,
		negative_z_action,
		positive_z_action,
		look_left_action,
		look_right_action,
		look_up_action,
		look_down_action,
		camera_center_action,
		jump_action,
		sprint_action,
		interact_action,
	]

	_actions_valid = U_InputMapBootstrapper.validate_required_actions(required_actions)
	if _actions_valid:
		return

	var missing: Array[StringName] = []
	for action in required_actions:
		if action == StringName():
			continue
		if not InputMap.has_action(action):
			missing.append(action)
	push_error("S_InputSystem: Missing required InputMap actions: %s (fix project.godot / boot init; system will not capture input)" % [missing])

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		return

	_teardown_store_subscription()

	# Use injected store if available (Phase 10B-8)
	var store: I_StateStore = null
	if state_store != null:
		store = state_store
	else:
		store = U_StateUtils.get_store(self)

	if store == null:
		return

	_state_store = store
	_store_unsubscribe = store.subscribe(_on_state_store_changed)
	_apply_settings_from_state(store.get_state())

func _get_state_store() -> I_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	_teardown_store_subscription()
	return null

func _on_state_store_changed(__action: Dictionary, state: Dictionary) -> void:
	_apply_settings_from_state(state)

func _is_gameplay_active_for_inputs() -> bool:
	var manager: I_ECSManager = get_manager()
	if manager == null:
		return true

	var character_entities: Array = manager.query_entities_readonly([CHARACTER_STATE_TYPE])
	if character_entities.is_empty():
		return true

	var has_character_state: bool = false
	for entity_query_variant in character_entities:
		var entity_query: Variant = entity_query_variant
		if entity_query == null:
			continue
		var character_state: C_CharacterStateComponent = entity_query.get_component(CHARACTER_STATE_TYPE)
		if character_state == null:
			continue
		has_character_state = true
		if character_state.is_gameplay_active:
			return true

	if not has_character_state:
		return true
	return false

func _apply_settings_from_state(state: Dictionary) -> void:
	if state == null:
		return

	var mouse_settings := U_InputSelectors.get_mouse_settings(state)
	var mouse_sensitivity := clampf(float(mouse_settings.get("sensitivity", 0.6)), 0.1, 5.0)
	var invert_y_axis := bool(mouse_settings.get("invert_y_axis", false))
	var keyboard_look_enabled := bool(mouse_settings.get("keyboard_look_enabled", true))
	var keyboard_look_speed := clampf(float(mouse_settings.get("keyboard_look_speed", 2.0)), 0.1, 10.0)

	var gamepad_settings := U_InputSelectors.get_gamepad_settings(state)
	_gamepad_settings_cache = gamepad_settings.duplicate(true)

	# Apply settings to input sources
	if _input_device_manager:
		var keyboard_mouse_source := _input_device_manager.get_input_source_for_device(DeviceType.KEYBOARD_MOUSE) as KeyboardMouseSource
		if keyboard_mouse_source:
			keyboard_mouse_source.set_sensitivity(mouse_sensitivity)
			keyboard_mouse_source.set_invert_y_axis(invert_y_axis)
			keyboard_mouse_source.set_keyboard_look_enabled(keyboard_look_enabled)
			keyboard_mouse_source.set_keyboard_look_speed(keyboard_look_speed)
			keyboard_mouse_source.look_left_action = look_left_action
			keyboard_mouse_source.look_right_action = look_right_action
			keyboard_mouse_source.look_up_action = look_up_action
			keyboard_mouse_source.look_down_action = look_down_action
			keyboard_mouse_source.camera_center_action = camera_center_action

		var gamepad_source := _input_device_manager.get_input_source_for_device(DeviceType.GAMEPAD) as GamepadSource
		if gamepad_source:
			gamepad_source.apply_settings(gamepad_settings)
			gamepad_source.camera_center_action = camera_center_action

func _teardown_store_subscription() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
	_state_store = null

func _exit_tree() -> void:
	_teardown_store_subscription()

func _debug_log_capture_snapshot(
	state: Dictionary,
	active_device_type: int,
	input_source: I_InputSource,
	look_delta: Vector2
) -> void:
	if not debug_input_logging:
		return
	var look_left_strength: float = Input.get_action_strength(look_left_action)
	var look_right_strength: float = Input.get_action_strength(look_right_action)
	var look_up_strength: float = Input.get_action_strength(look_up_action)
	var look_down_strength: float = Input.get_action_strength(look_down_action)

	var mouse_settings: Dictionary = U_InputSelectors.get_mouse_settings(state)
	var profile_id: String = U_InputSelectors.get_active_profile_id(state)
	var source_name: String = "null"
	if input_source != null:
		var source_script: Script = input_source.get_script() as Script
		if source_script != null:
			source_name = source_script.resource_path.get_file()
	var message := (
		"capture: device=%s source=%s profile=%s keyboard_look_enabled=%s keyboard_look_speed=%.3f "
		+ "look_strengths(L/R/U/D)=%.2f/%.2f/%.2f/%.2f look_events(L/R/U/D)=%d/%d/%d/%d look_delta=%s"
	) % [
		_device_type_to_string(active_device_type),
		source_name,
		profile_id,
		str(bool(mouse_settings.get("keyboard_look_enabled", true))),
		float(mouse_settings.get("keyboard_look_speed", 2.0)),
		look_left_strength,
		look_right_strength,
		look_up_strength,
		look_down_strength,
		InputMap.action_get_events(look_left_action).size(),
		InputMap.action_get_events(look_right_action).size(),
		InputMap.action_get_events(look_up_action).size(),
		InputMap.action_get_events(look_down_action).size(),
		str(look_delta),
	]
	_debug_log_input(message)

func _debug_log_input(message: String) -> void:
	if not debug_input_logging:
		return
	var interval: float = maxf(debug_log_interval_sec, 0.05)
	if not _debug_log_throttle.consume_budget(&"input/debug_log", interval):
		return
	_debug_log_throttle.log_message("S_InputSystem[debug]: %s" % message)

func _device_type_to_string(device_type: int) -> String:
	match device_type:
		DeviceType.KEYBOARD_MOUSE:
			return "keyboard_mouse"
		DeviceType.GAMEPAD:
			return "gamepad"
		DeviceType.TOUCHSCREEN:
			return "touchscreen"
		_:
			return "unknown(%d)" % device_type

func _mouse_mode_to_string(mouse_mode: int) -> String:
	match mouse_mode:
		Input.MOUSE_MODE_VISIBLE:
			return "visible"
		Input.MOUSE_MODE_HIDDEN:
			return "hidden"
		Input.MOUSE_MODE_CAPTURED:
			return "captured"
		Input.MOUSE_MODE_CONFINED:
			return "confined"
		Input.MOUSE_MODE_CONFINED_HIDDEN:
			return "confined_hidden"
		_:
			return "unknown(%d)" % mouse_mode
