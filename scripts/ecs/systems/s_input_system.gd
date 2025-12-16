@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_InputSystem

## Phase 16+: Dispatches keyboard/mouse/gamepad input to store and components.
## Delegates device-specific input capture to IInputSource implementations.

const INPUT_TYPE := StringName("C_InputComponent")
const GAMEPAD_TYPE := StringName("C_GamepadComponent")
const U_DeviceTypeConstants := preload("res://scripts/input/u_device_type_constants.gd")
const GamepadSource := preload("res://scripts/input/sources/gamepad_source.gd")
const KeyboardMouseSource := preload("res://scripts/input/sources/keyboard_mouse_source.gd")
const U_GameplaySelectors := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const C_GamepadComponent := preload("res://scripts/ecs/components/c_gamepad_component.gd")
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

var _actions_initialized := false
var _state_store: M_StateStore = null
var _store_unsubscribe: Callable = Callable()
var _input_device_manager: M_InputDeviceManager = null
var _gamepad_settings_cache: Dictionary = {}
var _sprint_toggle_enabled: bool = false
var _sprint_toggled_on: bool = false
var _sprint_button_was_pressed: bool = false

func on_configured() -> void:
	_ensure_actions()
	_ensure_state_store_ready()
	_ensure_input_device_manager()
	# Device connection/hotplug is handled by M_InputDeviceManager.
	# Input event capture is delegated to IInputSource implementations.

func _ensure_input_device_manager() -> void:
	if _input_device_manager != null and is_instance_valid(_input_device_manager):
		return
	var managers := get_tree().get_nodes_in_group("input_device_manager")
	if managers.is_empty():
		return
	_input_device_manager = managers[0] as M_InputDeviceManager

func process_tick(_delta: float) -> void:
	_ensure_actions()
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

func _ensure_actions() -> void:
	if _actions_initialized:
		return

	_ensure_action(
		negative_x_action,
		[KEY_A, KEY_LEFT],
		[JOY_BUTTON_DPAD_LEFT],
		[
			{"axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}
		]
	)
	_ensure_action(
		positive_x_action,
		[KEY_D, KEY_RIGHT],
		[JOY_BUTTON_DPAD_RIGHT],
		[
			{"axis": JOY_AXIS_LEFT_X, "axis_value": 1.0}
		]
	)
	_ensure_action(
		negative_z_action,
		[KEY_W, KEY_UP],
		[JOY_BUTTON_DPAD_UP],
		[
			{"axis": JOY_AXIS_LEFT_Y, "axis_value": -1.0}
		]
	)
	_ensure_action(
		positive_z_action,
		[KEY_S, KEY_DOWN],
		[JOY_BUTTON_DPAD_DOWN],
		[
			{"axis": JOY_AXIS_LEFT_Y, "axis_value": 1.0}
		]
	)
	_ensure_action(jump_action, [KEY_SPACE], [JOY_BUTTON_A])  # Bottom face button (PS Cross / Xbox A)
	_ensure_action(sprint_action, [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])  # L3 (left stick click)
	_ensure_action(interact_action, [KEY_E], [JOY_BUTTON_X])  # Left face button (PS Square / Xbox X)

	_actions_initialized = true

func _ensure_action(action_name: StringName, keys: Array, buttons: Array = [], motions: Array = []) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var events := InputMap.action_get_events(action_name)

	# Check if we already have keyboard keys
	var has_keyboard := false
	var has_gamepad_button := false
	var existing_motions: Array[Dictionary] = []
	for event in events:
		if event is InputEventKey:
			has_keyboard = true
		elif event is InputEventJoypadButton:
			has_gamepad_button = true
		elif event is InputEventJoypadMotion:
			var motion_event := event as InputEventJoypadMotion
			var sign := -1.0 if motion_event.axis_value < 0.0 else 1.0
			existing_motions.append({
				"axis": motion_event.axis,
				"axis_value": sign
			})

	# Add keyboard keys if missing
	if not has_keyboard:
		for key_code in keys:
			var event := InputEventKey.new()
			event.physical_keycode = key_code
			InputMap.action_add_event(action_name, event)

	# Add gamepad buttons if missing
	if not has_gamepad_button:
		for button_index in buttons:
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = button_index
			InputMap.action_add_event(action_name, button_event)

	# Add gamepad motion events (left stick axes) if missing
	for motion_data in motions:
		if not (motion_data is Dictionary):
			continue
		var axis := int((motion_data as Dictionary).get("axis", -1))
		var axis_value := float((motion_data as Dictionary).get("axis_value", 0.0))
		if axis == -1 or is_zero_approx(axis_value):
			continue
		var target_sign := -1.0 if axis_value < 0.0 else 1.0
		var already_present := false
		for existing in existing_motions:
			if int(existing.get("axis", -1)) == axis and float(existing.get("axis_value", 0.0)) == target_sign:
				already_present = true
				break
		if already_present:
			continue
		var motion_event := InputEventJoypadMotion.new()
		motion_event.axis = axis
		motion_event.axis_value = target_sign
		InputMap.action_add_event(action_name, motion_event)
		existing_motions.append({
			"axis": axis,
			"axis_value": target_sign
		})

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		return

	_teardown_store_subscription()

	var store := U_StateUtils.get_store(self)
	if store == null:
		return

	_state_store = store
	_store_unsubscribe = store.subscribe(_on_state_store_changed)
	_apply_settings_from_state(store.get_state())

func _get_state_store() -> M_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	_teardown_store_subscription()
	return null

func _on_state_store_changed(_action: Dictionary, state: Dictionary) -> void:
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
