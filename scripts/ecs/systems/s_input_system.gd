@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_InputSystem

## Phase 16+: Dispatches keyboard/mouse/gamepad input to store and components.
## Delegates device-specific input capture to IInputSource implementations.

const INPUT_TYPE := StringName("C_InputComponent")
const GAMEPAD_TYPE := StringName("C_GamepadComponent")
const ACTION_MOVE_STRENGTH := StringName("move")
const ACTION_LOOK_STRENGTH := StringName("look")

# Use centralized DeviceType enum
const DeviceType := U_DeviceTypeConstants.DeviceType

@export var negative_x_action: StringName = StringName("move_left")
@export var positive_x_action: StringName = StringName("move_right")
@export var negative_z_action: StringName = StringName("move_forward")
@export var positive_z_action: StringName = StringName("move_backward")
@export var jump_action: StringName = StringName("jump")
@export var sprint_action: StringName = StringName("sprint")
@export var interact_action: StringName = StringName("interact")
@export var input_deadzone: float = 0.15
@export var require_captured_cursor: bool = false

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
	_validate_required_actions()
	if not _actions_valid:
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
			return

	# Skip input capture if game is paused
	if store:
		var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
		if U_GameplaySelectors.get_is_paused(gameplay_state):
			return

	# Get active input source and delegate input capture
	var input_source: I_InputSource = null
	if _input_device_manager:
		input_source = _input_device_manager.get_input_source_for_device(active_device_type)

	if input_source == null:
		return

	# Capture input from active source
	var input_data := input_source.capture_input(_delta)
	var final_movement: Vector2 = input_data.get("move_input", Vector2.ZERO)
	var look_delta: Vector2 = input_data.get("look_input", Vector2.ZERO)
	var jump_pressed: bool = input_data.get("jump_pressed", false)
	var jump_just_pressed: bool = input_data.get("jump_just_pressed", false)
	var sprint_button_pressed: bool = input_data.get("sprint_pressed", false)

	# Apply sprint toggle if enabled
	var sprint_pressed := _compute_sprint_pressed(sprint_button_pressed)

	# Dispatch input to state store
	if store:
		store.dispatch(U_InputActions.update_move_input(final_movement))
		store.dispatch(U_InputActions.update_look_input(look_delta))
		store.dispatch(U_InputActions.update_jump_state(jump_pressed, jump_just_pressed))
		store.dispatch(U_InputActions.update_sprint_state(sprint_pressed))

	var move_strength := clampf(final_movement.length(), 0.0, 1.0)
	var look_strength := clampf(look_delta.length(), 0.0, 1.0)

	# Write to components (other systems read from them)
	var entities := query_entities([INPUT_TYPE], [GAMEPAD_TYPE])
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
			gamepad_component.is_connected = is_gamepad_connected
			gamepad_component.device_id = active_gamepad_id
			gamepad_component.apply_settings_from_dictionary(_gamepad_settings_cache)

func _update_accessibility_from_state(state: Dictionary) -> void:
	var settings_variant: Variant = state.get("settings", {})
	if not (settings_variant is Dictionary):
		_sprint_toggle_enabled = false
		return
	var settings_dict := settings_variant as Dictionary
	var input_settings_variant: Variant = settings_dict.get("input_settings", {})
	if not (input_settings_variant is Dictionary):
		_sprint_toggle_enabled = false
		return
	var input_settings := input_settings_variant as Dictionary
	var accessibility_variant: Variant = input_settings.get("accessibility", {})
	if not (accessibility_variant is Dictionary):
		_sprint_toggle_enabled = false
		return
	var accessibility := accessibility_variant as Dictionary
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

func _apply_settings_from_state(state: Dictionary) -> void:
	if state == null:
		return

	var mouse_settings := U_InputSelectors.get_mouse_settings(state)
	var mouse_sensitivity := clampf(float(mouse_settings.get("sensitivity", 1.0)), 0.0, 20.0)

	var gamepad_settings := U_InputSelectors.get_gamepad_settings(state)
	_gamepad_settings_cache = gamepad_settings.duplicate(true)

	# Apply settings to input sources
	if _input_device_manager:
		var keyboard_mouse_source := _input_device_manager.get_input_source_for_device(DeviceType.KEYBOARD_MOUSE) as KeyboardMouseSource
		if keyboard_mouse_source:
			keyboard_mouse_source.set_sensitivity(mouse_sensitivity)

		var gamepad_source := _input_device_manager.get_input_source_for_device(DeviceType.GAMEPAD) as GamepadSource
		if gamepad_source:
			gamepad_source.apply_settings(gamepad_settings)

func _teardown_store_subscription() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
	_state_store = null

func _exit_tree() -> void:
	_teardown_store_subscription()
