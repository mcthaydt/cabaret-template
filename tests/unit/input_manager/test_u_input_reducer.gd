extends GutTest

const INPUT_REDUCER := preload("res://scripts/state/reducers/u_input_reducer.gd")

func test_update_move_input_replaces_vector() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.update_move_input(Vector2(0.4, -0.2))
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_not_null(reduced)
	assert_eq(reduced.get("move_input"), Vector2(0.4, -0.2))
	assert_eq(state.get("move_input"), Vector2.ZERO, "Original state should remain unchanged")

func test_update_look_input_replaces_vector() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.update_look_input(Vector2(1.5, 0.25))
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_not_null(reduced)
	assert_eq(reduced.get("look_input"), Vector2(1.5, 0.25))

func test_update_camera_center_state_sets_just_pressed_flag() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.update_camera_center_state(true)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_not_null(reduced)
	assert_true(bool(reduced.get("camera_center_just_pressed", false)))

func test_update_jump_state_sets_flags() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.update_jump_state(true, true)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_true(reduced.get("jump_pressed", false))
	assert_true(reduced.get("jump_just_pressed", false))

func test_update_sprint_state_sets_flag() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.update_sprint_state(true)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_true(reduced.get("sprint_pressed", false))

func test_device_changed_updates_active_device_and_device_id() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.device_changed(1, 5)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_eq(reduced.get("active_device", 0), 1)
	assert_eq(reduced.get("gamepad_device_id", -1), 5)

func test_gamepad_connected_sets_connected_and_device_id() -> void:
	var state := _make_gameplay_state()
	var action := U_InputActions.gamepad_connected(2)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_true(reduced.get("gamepad_connected", false))
	assert_eq(reduced.get("gamepad_device_id", -1), 2)

func test_gamepad_disconnected_clears_connection_state() -> void:
	var state := _make_gameplay_state()
	state.gamepad_connected = true
	state.gamepad_device_id = 4
	var action := U_InputActions.gamepad_disconnected(4)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_false(reduced.get("gamepad_connected", true))
	assert_eq(reduced.get("gamepad_device_id", 0), -1)

func test_unhandled_action_returns_null_for_gameplay() -> void:
	var state := _make_gameplay_state()
	var action := {"type": StringName("noop"), "payload": {}}
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(state, action)
	assert_null(reduced)

func test_profile_switched_updates_active_profile_id() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.profile_switched("alt")
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	assert_not_null(reduced)
	assert_eq(reduced.get("active_profile_id", ""), "alt")

func test_rebind_action_stores_event_per_action() -> void:
	var settings := _make_settings_state()
	var event_data := {"type": "key", "keycode": KEY_E}
	var action := U_InputActions.rebind_action(StringName("interact"), event_data)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	var bindings: Dictionary = reduced.get("custom_bindings", {})
	assert_true(bindings.has(StringName("interact")))
	var events: Array = bindings[StringName("interact")] as Array
	assert_eq(events.size(), 1)
	assert_eq(events[0], event_data)

func test_reset_bindings_clears_custom_bindings() -> void:
	var settings := _make_settings_state()
	settings.custom_bindings = {StringName("jump"): [{"type": "key", "keycode": KEY_SPACE}]}
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, U_InputActions.reset_bindings())
	assert_true(reduced.get("custom_bindings", {}).is_empty())

func test_update_gamepad_deadzone_updates_requested_stick() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.update_gamepad_deadzone("left", 0.35)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	var pad_settings: Dictionary = reduced.get("gamepad_settings", {})
	assert_almost_eq(pad_settings.get("left_stick_deadzone", 0.0), 0.35, 0.0001)

func test_toggle_vibration_updates_flag() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.toggle_vibration(false)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	assert_false(reduced.get("gamepad_settings", {}).get("vibration_enabled", true))

func test_set_vibration_intensity_updates_value() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.set_vibration_intensity(0.4)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	assert_almost_eq(reduced.get("gamepad_settings", {}).get("vibration_intensity", 0.0), 0.4, 0.0001)

func test_update_mouse_sensitivity_updates_value() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.update_mouse_sensitivity(1.7)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	assert_almost_eq(reduced.get("mouse_settings", {}).get("sensitivity", 0.0), 1.7, 0.0001)

func test_set_keyboard_look_enabled_updates_value() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.set_keyboard_look_enabled(true)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	assert_true(reduced.get("mouse_settings", {}).get("keyboard_look_enabled", false))

func test_set_keyboard_look_speed_clamps_to_valid_range() -> void:
	var settings := _make_settings_state()
	var reduced_low: Variant = INPUT_REDUCER.reduce_input_settings(settings, U_InputActions.set_keyboard_look_speed(0.01))
	assert_almost_eq(reduced_low.get("mouse_settings", {}).get("keyboard_look_speed", 0.0), 0.1, 0.0001)
	var reduced_high: Variant = INPUT_REDUCER.reduce_input_settings(settings, U_InputActions.set_keyboard_look_speed(100.0))
	assert_almost_eq(reduced_high.get("mouse_settings", {}).get("keyboard_look_speed", 0.0), 10.0, 0.0001)

func test_update_accessibility_updates_field() -> void:
	var settings := _make_settings_state()
	var action := U_InputActions.update_accessibility("jump_buffer_time", 0.3)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	assert_almost_eq(reduced.get("accessibility", {}).get("jump_buffer_time", 0.0), 0.3, 0.0001)

func test_update_touchscreen_settings_merges_fields() -> void:
	var settings := _make_settings_state()
	var updates := {"virtual_joystick_opacity": 0.9, "button_size": 1.5, "look_drag_sensitivity": 99.0}
	var action := U_InputActions.update_touchscreen_settings(updates)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	var touchscreen_settings: Dictionary = reduced.get("touchscreen_settings", {})
	assert_almost_eq(touchscreen_settings.get("virtual_joystick_opacity", 0.0), 0.9, 0.0001)
	assert_almost_eq(touchscreen_settings.get("button_size", 0.0), 1.5, 0.0001)
	assert_almost_eq(touchscreen_settings.get("look_drag_sensitivity", 0.0), 5.0, 0.0001, "look_drag_sensitivity should clamp to max")
	assert_almost_eq(touchscreen_settings.get("joystick_deadzone", 0.0), 0.15, 0.0001, "Unmodified fields should retain defaults")

func test_save_virtual_control_position_stores_vector2_directly() -> void:
	var settings := _make_settings_state()
	var position := Vector2(120.0, 450.0)
	var action := U_InputActions.save_virtual_control_position("jump", position)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	var touchscreen_settings: Dictionary = reduced.get("touchscreen_settings", {})
	var custom_positions: Dictionary = touchscreen_settings.get("custom_button_positions", {})
	assert_true(custom_positions.has("jump"), "Custom position should be stored for jump button")
	var stored_position: Variant = custom_positions.get("jump", Vector2.ZERO)
	assert_true(stored_position is Vector2, "Position should be stored as Vector2, NOT dict")
	assert_almost_eq(stored_position.x, 120.0, 0.0001)
	assert_almost_eq(stored_position.y, 450.0, 0.0001)

func test_save_virtual_joystick_position_stores_vector2() -> void:
	var settings := _make_settings_state()
	var position := Vector2(80.0, 400.0)
	var action := U_InputActions.save_virtual_control_position("virtual_joystick", position)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(settings, action)
	var touchscreen_settings: Dictionary = reduced.get("touchscreen_settings", {})
	var joystick_position: Variant = touchscreen_settings.get("custom_joystick_position", Vector2.ZERO)
	assert_true(joystick_position is Vector2, "Joystick position should be Vector2")
	assert_almost_eq(joystick_position.x, 80.0, 0.0001)
	assert_almost_eq(joystick_position.y, 400.0, 0.0001)

func test_touchscreen_settings_have_required_default_fields() -> void:
	var settings := _make_settings_state()
	var touchscreen_settings: Dictionary = settings.get("touchscreen_settings", {})
	assert_true(touchscreen_settings.has("joystick_deadzone"), "Should have joystick_deadzone field")
	assert_true(touchscreen_settings.has("button_opacity"), "Should have button_opacity field")
	assert_true(touchscreen_settings.has("look_drag_sensitivity"), "Should have look_drag_sensitivity field")
	assert_true(touchscreen_settings.has("invert_look_y"), "Should have invert_look_y field")
	assert_true(touchscreen_settings.has("custom_joystick_position"), "Should have custom_joystick_position field")
	assert_true(touchscreen_settings.has("custom_button_positions"), "Should have custom_button_positions field")
	assert_true(touchscreen_settings.has("custom_button_sizes"), "Should have custom_button_sizes field")
	assert_true(touchscreen_settings.has("custom_button_opacities"), "Should have custom_button_opacities field")
	assert_almost_eq(touchscreen_settings.get("joystick_deadzone", 0.0), 0.15, 0.0001)
	assert_almost_eq(touchscreen_settings.get("button_opacity", 0.0), 0.8, 0.0001)
	assert_almost_eq(touchscreen_settings.get("look_drag_sensitivity", 0.0), 1.0, 0.0001)
	assert_false(bool(touchscreen_settings.get("invert_look_y", true)))
	var joystick_pos: Variant = touchscreen_settings.get("custom_joystick_position")
	assert_true(joystick_pos is Vector2, "custom_joystick_position should be Vector2")
	assert_eq(joystick_pos, Vector2(-1, -1), "Default joystick position should be sentinel value (-1, -1)")
	var button_sizes: Variant = touchscreen_settings.get("custom_button_sizes")
	assert_true(button_sizes is Dictionary, "custom_button_sizes should be Dictionary")
	assert_true(button_sizes.is_empty(), "custom_button_sizes should be empty by default")
	var button_opacities: Variant = touchscreen_settings.get("custom_button_opacities")
	assert_true(button_opacities is Dictionary, "custom_button_opacities should be Dictionary")
	assert_true(button_opacities.is_empty(), "custom_button_opacities should be empty by default")

func test_mouse_settings_have_keyboard_look_defaults() -> void:
	var settings := _make_settings_state()
	var mouse_settings: Dictionary = settings.get("mouse_settings", {})
	assert_almost_eq(float(mouse_settings.get("sensitivity", 0.0)), 0.6, 0.0001)
	assert_true(mouse_settings.has("keyboard_look_enabled"), "Should have keyboard_look_enabled field")
	assert_true(mouse_settings.has("keyboard_look_speed"), "Should have keyboard_look_speed field")
	assert_true(bool(mouse_settings.get("keyboard_look_enabled", false)))
	assert_almost_eq(float(mouse_settings.get("keyboard_look_speed", 0.0)), 2.0, 0.0001)

func test_gamepad_settings_have_balanced_orbit_defaults() -> void:
	var settings := _make_settings_state()
	var gamepad_settings: Dictionary = settings.get("gamepad_settings", {})
	assert_almost_eq(float(gamepad_settings.get("right_stick_deadzone", 0.0)), 0.16, 0.0001)
	assert_almost_eq(float(gamepad_settings.get("right_stick_sensitivity", 0.0)), 0.51, 0.0001)
	assert_eq(int(gamepad_settings.get("deadzone_curve", -1)), 1)

func test_reduce_settings_returns_null_for_unhandled_action() -> void:
	var action := {"type": StringName("noop")}
	assert_null(INPUT_REDUCER.reduce_input_settings(_make_settings_state(), action))

func _make_gameplay_state() -> Dictionary:
	return INPUT_REDUCER.get_default_gameplay_input_state()

func _make_settings_state() -> Dictionary:
	return INPUT_REDUCER.get_default_input_settings_state()
