extends GutTest

const U_InputSerialization := preload("res://scripts/utils/input/u_input_serialization.gd")
const U_InputReducer := preload("res://scripts/state/reducers/u_input_reducer.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")

func before_each() -> void:
	_cleanup_input_settings_files()

func after_each() -> void:
	_cleanup_input_settings_files()

func test_phase5_save_merges_touchscreen_defaults() -> void:
	var phase5_save := {
		"active_profile_id": "default",
		"custom_bindings": {},
		"gamepad_settings": {
			"left_stick_deadzone": 0.25
		}
	}
	_write_save_file(phase5_save)

	var loaded := U_InputSerialization.load_settings()
	var defaults := _get_touchscreen_defaults()
	var touchscreen: Dictionary = loaded.get("touchscreen_settings", {})

	assert_false(touchscreen.is_empty(), "Phase 5 saves should merge touchscreen defaults on load")
	for key in defaults.keys():
		assert_true(touchscreen.has(key), "Expected touchscreen_settings to include %s" % key)
		assert_eq(touchscreen[key], defaults[key], "Default %s should be applied when missing" % key)

func test_partial_touchscreen_settings_fill_defaults() -> void:
	var partial_save := {
		"active_profile_id": "default",
		"touchscreen_settings": {
			"virtual_joystick_size": 1.25,
			"custom_joystick_position": {
				"x": 42.0,
				"y": 64.0
			}
		}
	}
	_write_save_file(partial_save)

	var loaded := U_InputSerialization.load_settings()
	var defaults := _get_touchscreen_defaults()
	var touchscreen: Dictionary = loaded.get("touchscreen_settings", {})

	assert_almost_eq(touchscreen.get("virtual_joystick_size", 0.0), 1.25, 0.0001,
		"Existing touchscreen values should be preserved")
	assert_almost_eq(touchscreen.get("joystick_deadzone", 0.0), defaults.get("joystick_deadzone", 0.0), 0.0001,
		"Missing touchscreen fields should be backfilled with defaults")
	var joystick_pos: Variant = touchscreen.get("custom_joystick_position")
	assert_true(joystick_pos is Vector2, "Joystick position should deserialize to Vector2")
	assert_vector_almost_eq(joystick_pos, Vector2(42.0, 64.0), 0.0001,
		"Joystick Vector2 should restore from {x,y} dictionary")

func test_vector2_fields_deserialize_from_dicts() -> void:
	var save_data := {
		"touchscreen_settings": {
			"custom_joystick_position": {
				"x": 120.0,
				"y": 340.0
			},
			"custom_button_positions": {
				"jump": {
					"x": 640.0,
					"y": 420.0
				}
			}
		}
	}
	_write_save_file(save_data)

	var loaded := U_InputSerialization.load_settings()
	var touchscreen: Dictionary = loaded.get("touchscreen_settings", {})
	var joystick_pos: Variant = touchscreen.get("custom_joystick_position")
	assert_true(joystick_pos is Vector2, "Joystick position should load as Vector2 from dict")
	assert_vector_almost_eq(joystick_pos, Vector2(120.0, 340.0), 0.0001)

	var button_positions: Dictionary = touchscreen.get("custom_button_positions", {})
	var jump_pos: Variant = button_positions.get(StringName("jump"), button_positions.get("jump"))
	assert_true(jump_pos is Vector2, "Button position should load as Vector2 from dict")
	assert_vector_almost_eq(jump_pos, Vector2(640.0, 420.0), 0.0001)

func test_roundtrip_normalizes_custom_button_keys() -> void:
	var phase5_save := {
		"active_profile_id": "default"
	}
	_write_save_file(phase5_save)

	var loaded := U_InputSerialization.load_settings()
	var touchscreen: Dictionary = loaded.get("touchscreen_settings", {})
	touchscreen["custom_joystick_position"] = Vector2(300, 200)
	touchscreen["custom_button_positions"] = {
		StringName("jump"): Vector2(640, 420),
		"sprint": Vector2(720, 420)
	}
	loaded["touchscreen_settings"] = touchscreen

	var save_success := U_InputSerialization.save_settings(loaded)
	assert_true(save_success, "Save should succeed after customizing positions")

	var roundtrip := U_InputSerialization.load_settings()
	var roundtrip_touchscreen: Dictionary = roundtrip.get("touchscreen_settings", {})
	var custom_positions: Dictionary = roundtrip_touchscreen.get("custom_button_positions", {})

	assert_true(custom_positions.has(StringName("jump")), "Custom button keys should normalize to StringName for runtime use")
	assert_true(custom_positions.has(StringName("sprint")), "Custom button keys should normalize consistently")
	assert_vector_almost_eq(custom_positions.get(StringName("jump")), Vector2(640, 420), 0.0001,
		"Jump position should persist across save/load")
	assert_vector_almost_eq(custom_positions.get(StringName("sprint")), Vector2(720, 420), 0.0001,
		"Sprint position should persist across save/load")

	var state := {
		"settings": {
			"input_settings": roundtrip
		}
	}
	var sprint_position: Variant = U_InputSelectors.get_virtual_control_position(state, "sprint")
	assert_true(sprint_position is Vector2, "Selectors should resolve positions with normalized keys")
	assert_vector_almost_eq(sprint_position, Vector2(720, 420), 0.0001)

func _get_touchscreen_defaults() -> Dictionary:
	var defaults := U_InputReducer.get_default_input_settings_state()
	return defaults.get("touchscreen_settings", {}).duplicate(true)

func _write_save_file(data: Dictionary) -> void:
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open("user://input_settings.json", FileAccess.WRITE)
	assert_not_null(file, "Should open input_settings.json for writing")
	file.store_string(json)
	file.flush()
	file = null

func _cleanup_input_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("input_settings.json"):
		dir.remove("input_settings.json")
	if dir.file_exists("input_settings.json.backup"):
		dir.remove("input_settings.json.backup")

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")
