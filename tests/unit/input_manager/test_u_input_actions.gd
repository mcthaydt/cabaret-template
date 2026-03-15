extends GutTest

const SAMPLE_MOVE := Vector2(0.5, -0.25)
const SAMPLE_LOOK := Vector2(2.0, -1.0)

func test_action_constants_are_string_names() -> void:
	for constant in _get_action_constants():
		assert_true(constant is StringName, "Action constants should be StringName")

func test_actions_register_with_action_registry() -> void:
	for constant in _get_action_constants():
		assert_true(U_ActionRegistry.is_registered(constant), "Action should be registered: %s" % [String(constant)])

func test_update_move_input_returns_payload() -> void:
	var action := U_InputActions.update_move_input(SAMPLE_MOVE)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_MOVE_INPUT)
	assert_almost_eq(payload.get("move_vector", Vector2.ZERO).x, SAMPLE_MOVE.x, 0.0001)
	assert_almost_eq(payload.get("move_vector", Vector2.ZERO).y, SAMPLE_MOVE.y, 0.0001)

func test_update_look_input_returns_payload() -> void:
	var action := U_InputActions.update_look_input(SAMPLE_LOOK)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_LOOK_INPUT)
	assert_almost_eq(payload.get("look_delta", Vector2.ZERO).x, SAMPLE_LOOK.x, 0.0001)
	assert_almost_eq(payload.get("look_delta", Vector2.ZERO).y, SAMPLE_LOOK.y, 0.0001)

func test_update_aim_state_returns_payload() -> void:
	var action := U_InputActions.update_aim_state(true)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_AIM_STATE)
	assert_true(payload.get("pressed", false))

func test_update_camera_center_state_returns_payload() -> void:
	var action := U_InputActions.update_camera_center_state(true)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_CAMERA_CENTER_STATE)
	assert_true(payload.get("just_pressed", false))

func test_update_jump_state_includes_press_flags() -> void:
	var action := U_InputActions.update_jump_state(true, false)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_JUMP_STATE)
	assert_true(payload.get("pressed", false))
	assert_false(payload.get("just_pressed", true))

func test_update_sprint_state_includes_pressed_flag() -> void:
	var action := U_InputActions.update_sprint_state(true)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_SPRINT_STATE)
	assert_true(payload.get("pressed", false))

func test_device_changed_defaults_device_id_to_negative_one() -> void:
	var action := U_InputActions.device_changed(1)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_DEVICE_CHANGED)
	assert_eq(payload.get("device_type", -1), 1)
	assert_eq(payload.get("device_id", 0), -1)

func test_device_changed_accepts_explicit_device_id() -> void:
	var action := U_InputActions.device_changed(2, 7)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_DEVICE_CHANGED)
	assert_eq(payload.get("device_type", -1), 2)
	assert_eq(payload.get("device_id", -1), 7)

func test_gamepad_connected_payload_contains_id() -> void:
	var action := U_InputActions.gamepad_connected(3)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_GAMEPAD_CONNECTED)
	assert_eq(payload.get("device_id", -1), 3)

func test_gamepad_disconnected_payload_contains_id() -> void:
	var action := U_InputActions.gamepad_disconnected(4)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_GAMEPAD_DISCONNECTED)
	assert_eq(payload.get("device_id", -1), 4)

func test_profile_switched_payload_contains_profile_id() -> void:
	var action := U_InputActions.profile_switched("accessibility")
	var payload := _assert_action_structure(action, U_InputActions.ACTION_PROFILE_SWITCHED)
	assert_eq(payload.get("profile_id", ""), "accessibility")

func test_rebind_action_payload_contains_action_and_event() -> void:
	var event_data := {"type": "key", "keycode": 32}
	var action := U_InputActions.rebind_action(StringName("jump"), event_data)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_REBIND_ACTION)
	assert_eq(payload.get("action", StringName("")), StringName("jump"))
	assert_eq(payload.get("event", {}), event_data)
	assert_true(action.get("immediate", false), "Rebind actions should set immediate flag")
	var events_variant: Variant = payload.get("events", [])
	assert_true(events_variant is Array, "Rebind payload should include canonical events array")

func test_reset_bindings_returns_empty_payload_dictionary() -> void:
	var action := U_InputActions.reset_bindings()
	var payload := _assert_action_structure(action, U_InputActions.ACTION_RESET_BINDINGS)
	assert_true(payload.is_empty(), "Reset bindings payload should be empty dictionary")
	assert_true(action.get("immediate", false), "Reset bindings must flush immediately so InputMap updates same frame")

func test_other_actions_do_not_set_immediate_flag() -> void:
	var move_action := U_InputActions.update_move_input(SAMPLE_MOVE)
	assert_false(move_action.get("immediate", false), "Non-rebind actions should not set immediate flag")

func test_update_gamepad_deadzone_payload_contains_stick_and_value() -> void:
	var action := U_InputActions.update_gamepad_deadzone("left", 0.42)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_GAMEPAD_DEADZONE)
	assert_eq(payload.get("stick", ""), "left")
	assert_almost_eq(payload.get("deadzone", 0.0), 0.42, 0.0001)

func test_toggle_vibration_payload_contains_enabled_flag() -> void:
	var action := U_InputActions.toggle_vibration(false)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_TOGGLE_VIBRATION)
	assert_false(payload.get("enabled", true))

func test_set_vibration_intensity_payload_contains_value() -> void:
	var action := U_InputActions.set_vibration_intensity(0.75)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_SET_VIBRATION_INTENSITY)
	assert_almost_eq(payload.get("intensity", 0.0), 0.75, 0.0001)

func test_update_mouse_sensitivity_payload_contains_value() -> void:
	var action := U_InputActions.update_mouse_sensitivity(1.5)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_MOUSE_SENSITIVITY)
	assert_almost_eq(payload.get("sensitivity", 0.0), 1.5, 0.0001)

func test_update_accessibility_payload_contains_field_and_value() -> void:
	var action := U_InputActions.update_accessibility("jump_buffer_time", 0.3)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_ACCESSIBILITY)
	assert_eq(payload.get("field", ""), "jump_buffer_time")
	assert_almost_eq(payload.get("value", 0.0), 0.3, 0.0001)

func test_update_touchscreen_settings_payload_contains_settings() -> void:
	var settings := {"virtual_joystick_opacity": 0.8, "button_size": 1.2}
	var action := U_InputActions.update_touchscreen_settings(settings)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS)
	assert_eq(payload.get("settings", {}), settings)

func test_save_virtual_control_position_accepts_vector2() -> void:
	var position := Vector2(120.0, 450.0)
	var action := U_InputActions.save_virtual_control_position("jump", position)
	var payload := _assert_action_structure(action, U_InputActions.ACTION_SAVE_VIRTUAL_CONTROL_POSITION)
	assert_eq(payload.get("control_name", ""), "jump")
	var stored_position: Variant = payload.get("position", Vector2.ZERO)
	assert_true(stored_position is Vector2, "Position should be stored as Vector2, not dict")
	assert_almost_eq(stored_position.x, 120.0, 0.0001)
	assert_almost_eq(stored_position.y, 450.0, 0.0001)

func test_created_actions_validate_with_action_registry() -> void:
	var actions := [
		U_InputActions.update_move_input(SAMPLE_MOVE),
		U_InputActions.update_look_input(SAMPLE_LOOK),
		U_InputActions.update_aim_state(true),
		U_InputActions.update_camera_center_state(true),
		U_InputActions.update_jump_state(true, true),
		U_InputActions.update_sprint_state(false),
		U_InputActions.device_changed(0, -1),
		U_InputActions.gamepad_connected(1),
		U_InputActions.gamepad_disconnected(1),
		U_InputActions.profile_switched("default"),
		U_InputActions.rebind_action(StringName("move_forward"), {"type": "key", "keycode": 87}),
		U_InputActions.reset_bindings(),
		U_InputActions.update_gamepad_deadzone("right", 0.2),
		U_InputActions.toggle_vibration(true),
		U_InputActions.set_vibration_intensity(0.5),
		U_InputActions.update_mouse_sensitivity(0.9),
		U_InputActions.update_accessibility("sprint_toggle_mode", true),
		U_InputActions.update_touchscreen_settings({"button_size": 1.0}),
		U_InputActions.save_virtual_control_position("jump", Vector2(800, 450)),
	]
	for action in actions:
		assert_true(U_ActionRegistry.validate_action(action), "Action should validate: %s" % [String(action.get("type"))])

func _assert_action_structure(action: Dictionary, expected_type: StringName) -> Dictionary:
	assert_true(action.has("type"), "Action should have type field")
	assert_true(action.has("payload"), "Action should have payload field")
	assert_eq(action.get("type"), expected_type, "Unexpected action type")
	var payload: Variant = action.get("payload")
	assert_true(payload is Dictionary, "Payload should be a Dictionary")
	return payload

func _get_action_constants() -> Array[StringName]:
	return [
		U_InputActions.ACTION_UPDATE_MOVE_INPUT,
		U_InputActions.ACTION_UPDATE_LOOK_INPUT,
		U_InputActions.ACTION_UPDATE_AIM_STATE,
		U_InputActions.ACTION_UPDATE_CAMERA_CENTER_STATE,
		U_InputActions.ACTION_UPDATE_JUMP_STATE,
		U_InputActions.ACTION_UPDATE_SPRINT_STATE,
		U_InputActions.ACTION_DEVICE_CHANGED,
		U_InputActions.ACTION_GAMEPAD_CONNECTED,
		U_InputActions.ACTION_GAMEPAD_DISCONNECTED,
		U_InputActions.ACTION_PROFILE_SWITCHED,
		U_InputActions.ACTION_REBIND_ACTION,
		U_InputActions.ACTION_RESET_BINDINGS,
		U_InputActions.ACTION_UPDATE_GAMEPAD_DEADZONE,
		U_InputActions.ACTION_TOGGLE_VIBRATION,
		U_InputActions.ACTION_SET_VIBRATION_INTENSITY,
		U_InputActions.ACTION_UPDATE_MOUSE_SENSITIVITY,
		U_InputActions.ACTION_UPDATE_ACCESSIBILITY,
		U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS,
		U_InputActions.ACTION_SAVE_VIRTUAL_CONTROL_POSITION,
	]
