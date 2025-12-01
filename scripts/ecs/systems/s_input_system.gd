@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_InputSystem

## Phase 16+: Dispatches keyboard/mouse/gamepad input to store and components.

const INPUT_TYPE := StringName("C_InputComponent")
const GAMEPAD_TYPE := StringName("C_GamepadComponent")
const RS_GamepadSettings := preload("res://scripts/ecs/resources/rs_gamepad_settings.gd")
const U_GameplaySelectors := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const C_GamepadComponent := preload("res://scripts/ecs/components/c_gamepad_component.gd")
const ACTION_MOVE_STRENGTH := StringName("move")
const ACTION_LOOK_STRENGTH := StringName("look")

enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD,
	TOUCHSCREEN,
}

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
var _mouse_delta: Vector2 = Vector2.ZERO
var _state_store: M_StateStore = null
var _store_unsubscribe: Callable = Callable()
var _mouse_sensitivity: float = 1.0
var _left_stick_raw: Vector2 = Vector2.ZERO
var _right_stick_raw: Vector2 = Vector2.ZERO
var _gamepad_left_stick: Vector2 = Vector2.ZERO
var _gamepad_right_stick: Vector2 = Vector2.ZERO
var _button_states: Dictionary = {}
var _gamepad_settings_cache: Dictionary = {}
var _left_stick_deadzone: float = 0.2
var _right_stick_deadzone: float = 0.2
var _deadzone_curve: int = RS_GamepadSettings.DeadzoneCurve.LINEAR
var _right_stick_sensitivity: float = 1.0
var _invert_right_stick_y: bool = false
var _sprint_toggle_enabled: bool = false
var _sprint_toggled_on: bool = false
var _sprint_button_was_pressed: bool = false

func on_configured() -> void:
	_ensure_actions()
	# Enable input processing for mouse capture
	set_process_input(true)
	set_process_unhandled_input(true)
	_ensure_state_store_ready()
	# Device connection/hotplug is handled by M_InputDeviceManager.

func _input(event: InputEvent) -> void:
	# Capture mouse movement for look input
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative
	elif event is InputEventJoypadMotion:
		_handle_joypad_motion(event as InputEventJoypadMotion)
	elif event is InputEventJoypadButton:
		_handle_joypad_button(event as InputEventJoypadButton)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_handle_joypad_motion(event as InputEventJoypadMotion)
	elif event is InputEventJoypadButton:
		_handle_joypad_button(event as InputEventJoypadButton)

func process_tick(_delta: float) -> void:
	_ensure_actions()

	_ensure_state_store_ready()
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
		# Fallback: if the store reports an active gamepad with a valid id,
		# treat it as connected even if the connection flag missed a platform-specific event.
		if active_device_type == DeviceType.GAMEPAD and active_gamepad_id >= 0:
			is_gamepad_connected = true

	# Only gate input on cursor capture for desktop platforms.
	# On mobile, there is no mouse cursor concept, and gating here would
	# prevent gamepad input when the virtual touchscreen hides.
	if not OS.has_feature("mobile"):
		if require_captured_cursor and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_mouse_delta = Vector2.ZERO
			return

	if not is_gamepad_connected:
		_reset_gamepad_state()

	# Skip input capture if game is paused
	if store:
		var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
		if U_GameplaySelectors.get_is_paused(gameplay_state):
			_mouse_delta = Vector2.ZERO
			_gamepad_left_stick = Vector2.ZERO
			_gamepad_right_stick = Vector2.ZERO
			return

	var keyboard_vector := Input.get_vector(negative_x_action, positive_x_action, negative_z_action, positive_z_action)
	if keyboard_vector.length() > 0.0 and keyboard_vector.length() < input_deadzone:
		keyboard_vector = Vector2.ZERO
	var jump_pressed := Input.is_action_pressed(jump_action)
	var jump_just_pressed := Input.is_action_just_pressed(jump_action)
	var sprint_button_pressed := Input.is_action_pressed(sprint_action)
	var sprint_pressed := _compute_sprint_pressed(sprint_button_pressed)

	var final_movement := keyboard_vector
	if active_device_type == DeviceType.GAMEPAD:
		final_movement = _gamepad_left_stick
	elif _gamepad_left_stick.length() > final_movement.length():
		final_movement = _gamepad_left_stick

	var look_delta := Vector2.ZERO
	if active_device_type == DeviceType.GAMEPAD:
		look_delta = _gamepad_right_stick * _right_stick_sensitivity
	else:
		look_delta = _mouse_delta * _mouse_sensitivity
	if look_delta.is_zero_approx() and not _gamepad_right_stick.is_zero_approx():
		look_delta = _gamepad_right_stick * _right_stick_sensitivity

	# Dispatch input to state store
	if store:
		store.dispatch(U_InputActions.update_move_input(final_movement))
		store.dispatch(U_InputActions.update_look_input(look_delta))
		store.dispatch(U_InputActions.update_jump_state(jump_pressed, jump_just_pressed))
		store.dispatch(U_InputActions.update_sprint_state(sprint_pressed))
	
	_mouse_delta = Vector2.ZERO

	var move_strength := clampf(final_movement.length(), 0.0, 1.0)
	var look_strength := clampf(look_delta.length(), 0.0, 1.0)

	# Still write to components (other systems read from them)
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
			gamepad_component.left_stick = _gamepad_left_stick
			gamepad_component.right_stick = _gamepad_right_stick
			gamepad_component.is_connected = is_gamepad_connected
			gamepad_component.device_id = active_gamepad_id
			gamepad_component.apply_settings_from_dictionary(_gamepad_settings_cache)
			gamepad_component.button_states = _button_states.duplicate(true)

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
	var target := float(mouse_settings.get("sensitivity", 1.0))
	_mouse_sensitivity = clampf(target, 0.0, 20.0)

	var gamepad_settings := U_InputSelectors.get_gamepad_settings(state)
	_gamepad_settings_cache = gamepad_settings.duplicate(true)
	_left_stick_deadzone = clampf(float(gamepad_settings.get("left_stick_deadzone", 0.2)), 0.0, 1.0)
	_right_stick_deadzone = clampf(float(gamepad_settings.get("right_stick_deadzone", 0.2)), 0.0, 1.0)
	_right_stick_sensitivity = clampf(float(gamepad_settings.get("right_stick_sensitivity", 1.0)), 0.0, 5.0)
	_invert_right_stick_y = bool(gamepad_settings.get("invert_y_axis", false))
	_deadzone_curve = int(gamepad_settings.get("deadzone_curve", RS_GamepadSettings.DeadzoneCurve.LINEAR))

func _teardown_store_subscription() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
	_state_store = null

func _exit_tree() -> void:
	_teardown_store_subscription()

func _handle_joypad_motion(event: InputEventJoypadMotion) -> void:
	if event == null:
		return
	if event.device >= 0:
		var active_gamepad_id := _get_active_gamepad_id_from_store()
		if active_gamepad_id >= 0 and event.device != active_gamepad_id:
			return
	match event.axis:
		JOY_AXIS_LEFT_X:
			_left_stick_raw.x = event.axis_value
		JOY_AXIS_LEFT_Y:
			_left_stick_raw.y = event.axis_value
		JOY_AXIS_RIGHT_X:
			_right_stick_raw.x = event.axis_value
		JOY_AXIS_RIGHT_Y:
			_right_stick_raw.y = event.axis_value
		_:
			pass

	_gamepad_left_stick = RS_GamepadSettings.apply_deadzone(
		_left_stick_raw,
		_left_stick_deadzone,
		_deadzone_curve
	)
	var right_y := _right_stick_raw.y
	if _invert_right_stick_y:
		right_y = -right_y
	var right_processed := Vector2(_right_stick_raw.x, right_y)
	_gamepad_right_stick = RS_GamepadSettings.apply_deadzone(
		right_processed,
		_right_stick_deadzone,
		_deadzone_curve
	)

func _handle_joypad_button(event: InputEventJoypadButton) -> void:
	if event == null:
		return
	if event.device >= 0:
		var active_gamepad_id := _get_active_gamepad_id_from_store()
		if active_gamepad_id >= 0 and event.device != active_gamepad_id:
			return
	_button_states[event.button_index] = event.pressed


func _get_active_gamepad_id_from_store() -> int:
	var store := _get_state_store()
	if store == null:
		return -1
	return U_InputSelectors.get_active_gamepad_id(store.get_state())

func _reset_gamepad_state() -> void:
	_left_stick_raw = Vector2.ZERO
	_right_stick_raw = Vector2.ZERO
	_gamepad_left_stick = Vector2.ZERO
	_gamepad_right_stick = Vector2.ZERO
	_button_states.clear()
