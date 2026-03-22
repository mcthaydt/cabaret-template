extends GutTest

const SAMPLE_STATE := {
	"gameplay": {
		"input": {
			"active_device": 1,
			"last_input_time": 12.5,
			"gamepad_connected": true,
			"gamepad_device_id": 3,
			"touchscreen_enabled": false,
			"move_input": Vector2(0.25, -0.75),
			"look_input": Vector2(1.0, -0.5),
			"camera_center_just_pressed": true,
			"jump_pressed": true,
			"jump_just_pressed": false,
			"sprint_pressed": true,
		}
	},
	"settings": {
		"input_settings": {
			"active_profile_id": "accessibility",
			"custom_bindings": {},
			"gamepad_settings": {"left_stick_deadzone": 0.15},
			"mouse_settings": {"sensitivity": 1.3},
		}
	}
}

func test_get_active_device_returns_value_when_present() -> void:
	assert_eq(U_InputSelectors.get_active_device(SAMPLE_STATE), 1)

func test_get_active_device_defaults_to_keyboard_mouse() -> void:
	assert_eq(U_InputSelectors.get_active_device({}), 0)

func test_get_active_device_type_reads_top_level_input_slice() -> void:
	var state := {
		"input": {
			"active_device_type": 2
		},
		"gameplay": {
			"input": {
				"active_device": 1
			}
		}
	}
	assert_eq(U_InputSelectors.get_active_device_type(state), 2)

func test_get_active_device_type_falls_back_to_gameplay_input() -> void:
	assert_eq(U_InputSelectors.get_active_device_type(SAMPLE_STATE), 1)

func test_get_active_gamepad_id_reads_top_level_input_slice() -> void:
	var state := {
		"input": {
			"active_gamepad_id": 6
		}
	}
	assert_eq(U_InputSelectors.get_active_gamepad_id(state), 6)

func test_get_active_gamepad_id_falls_back_to_legacy_field() -> void:
	assert_eq(U_InputSelectors.get_active_gamepad_id(SAMPLE_STATE), 3)

func test_get_move_input_returns_vector() -> void:
	var move_input := U_InputSelectors.get_move_input(SAMPLE_STATE)
	assert_almost_eq(move_input.x, 0.25, 0.0001)
	assert_almost_eq(move_input.y, -0.75, 0.0001)

func test_get_move_input_defaults_to_zero_vector() -> void:
	var move_input := U_InputSelectors.get_move_input({})
	assert_eq(move_input, Vector2.ZERO)

func test_get_look_input_returns_value() -> void:
	var look_input := U_InputSelectors.get_look_input(SAMPLE_STATE)
	assert_almost_eq(look_input.x, 1.0, 0.0001)
	assert_almost_eq(look_input.y, -0.5, 0.0001)

func test_get_look_input_defaults_to_zero_vector() -> void:
	assert_eq(U_InputSelectors.get_look_input({}), Vector2.ZERO)

func test_is_camera_center_just_pressed_returns_flag() -> void:
	assert_true(U_InputSelectors.is_camera_center_just_pressed(SAMPLE_STATE))

func test_is_camera_center_just_pressed_defaults_to_false() -> void:
	assert_false(U_InputSelectors.is_camera_center_just_pressed({}))

func test_is_jump_pressed_returns_flag() -> void:
	assert_true(U_InputSelectors.is_jump_pressed(SAMPLE_STATE))

func test_is_jump_pressed_defaults_to_false() -> void:
	assert_false(U_InputSelectors.is_jump_pressed({}))

func test_is_sprint_pressed_returns_flag() -> void:
	assert_true(U_InputSelectors.is_sprint_pressed(SAMPLE_STATE))

func test_is_sprint_pressed_defaults_to_false() -> void:
	assert_false(U_InputSelectors.is_sprint_pressed({}))

func test_is_gamepad_connected_returns_flag() -> void:
	assert_true(U_InputSelectors.is_gamepad_connected(SAMPLE_STATE))

func test_get_gamepad_device_id_returns_value() -> void:
	assert_eq(U_InputSelectors.get_gamepad_device_id(SAMPLE_STATE), 3)

func test_get_gamepad_device_id_defaults_to_negative_one() -> void:
	assert_eq(U_InputSelectors.get_gamepad_device_id({}), -1)

func test_get_active_profile_id_returns_settings_value() -> void:
	assert_eq(U_InputSelectors.get_active_profile_id(SAMPLE_STATE), "accessibility")

func test_get_active_profile_id_defaults_to_default() -> void:
	assert_eq(U_InputSelectors.get_active_profile_id({}), "default")

func test_get_gamepad_settings_returns_dictionary_copy() -> void:
	var settings := U_InputSelectors.get_gamepad_settings(SAMPLE_STATE)
	assert_false(settings.is_empty())
	settings.left_stick_deadzone = 0.5
	assert_almost_eq(SAMPLE_STATE.settings.input_settings.gamepad_settings.left_stick_deadzone, 0.15, 0.0001, "Selector should return copy")

func test_get_mouse_settings_returns_dictionary_copy() -> void:
	var settings := U_InputSelectors.get_mouse_settings(SAMPLE_STATE)
	assert_almost_eq(settings.get("sensitivity", 0.0), 1.3, 0.0001)
	settings.sensitivity = 0.5
	assert_almost_eq(SAMPLE_STATE.settings.input_settings.mouse_settings.sensitivity, 1.3, 0.0001, "Selector should return copy")

func test_get_gamepad_settings_defaults_to_empty_dictionary() -> void:
	assert_true(U_InputSelectors.get_gamepad_settings({}).is_empty())

func test_get_mouse_settings_defaults_to_empty_dictionary() -> void:
	assert_true(U_InputSelectors.get_mouse_settings({}).is_empty())

func test_get_touchscreen_settings_returns_dictionary_with_vector2_fields() -> void:
	var state := {
		"settings": {
			"input_settings": {
				"touchscreen_settings": {
					"joystick_deadzone": 0.2,
					"button_opacity": 0.9,
					"custom_joystick_position": Vector2(100, 400),
					"custom_button_positions": {
						"jump": Vector2(800, 450)
					}
				}
			}
		}
	}
	var settings := U_InputSelectors.get_touchscreen_settings(state)
	assert_almost_eq(settings.get("joystick_deadzone", 0.0), 0.2, 0.0001)
	assert_almost_eq(settings.get("button_opacity", 0.0), 0.9, 0.0001)
	var joystick_pos = settings.get("custom_joystick_position")
	assert_true(joystick_pos is Vector2, "custom_joystick_position should be Vector2")
	assert_eq(joystick_pos, Vector2(100, 400))

func test_get_touchscreen_settings_defaults_to_empty_dictionary() -> void:
	assert_true(U_InputSelectors.get_touchscreen_settings({}).is_empty())

func test_get_virtual_control_position_returns_custom_position_when_set() -> void:
	var state := {
		"settings": {
			"input_settings": {
				"touchscreen_settings": {
					"custom_button_positions": {
						"jump": Vector2(750, 400)
					}
				}
			}
		}
	}
	var position = U_InputSelectors.get_virtual_control_position(state, "jump")
	assert_true(position is Vector2, "Position should be Vector2")
	assert_eq(position, Vector2(750, 400))

func test_get_virtual_control_position_ignores_sentinel_value() -> void:
	var state := {
		"settings": {
			"input_settings": {
				"touchscreen_settings": {
					"custom_joystick_position": Vector2(-1, -1)
				}
			}
		}
	}
	var position = U_InputSelectors.get_virtual_control_position(state, "virtual_joystick")
	assert_null(position, "Sentinel value (-1, -1) should return null to fall back to profile default")

func test_get_virtual_control_position_returns_null_when_not_customized() -> void:
	var state := {
		"settings": {
			"input_settings": {
				"touchscreen_settings": {}
			}
		}
	}
	var position = U_InputSelectors.get_virtual_control_position(state, "jump")
	assert_null(position, "Non-customized button should return null to fall back to profile default")
