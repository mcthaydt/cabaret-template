extends GutTest

const U_GLOBAL_SETTINGS_SERIALIZATION := preload("res://scripts/utils/u_global_settings_serialization.gd")

func before_each() -> void:
	_cleanup_global_settings_files()

func after_each() -> void:
	_cleanup_global_settings_files()

func test_save_and_load_preserves_vector2_joystick_position() -> void:
	var settings := {
		"active_profile_id": "default",
		"touchscreen_settings": {
			"custom_joystick_position": Vector2(120.0, 450.0),
			"joystick_deadzone": 0.15
		}
	}

	var saved := U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})
	assert_true(saved, "Save should succeed")

	var loaded := U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	assert_not_null(loaded, "Load should succeed")

	var input_settings: Dictionary = loaded.get("input_settings", {})
	var touchscreen: Dictionary = input_settings.get("touchscreen_settings", {})
	var joystick_pos: Variant = touchscreen.get("custom_joystick_position")

	assert_true(joystick_pos is Vector2, "Loaded joystick position should be Vector2, not dict")
	assert_almost_eq(joystick_pos.x, 120.0, 0.0001)
	assert_almost_eq(joystick_pos.y, 450.0, 0.0001)

func test_save_and_load_preserves_vector2_button_positions() -> void:
	var settings := {
		"active_profile_id": "default",
		"touchscreen_settings": {
			"custom_button_positions": {
				"jump": Vector2(800.0, 450.0),
				"sprint": Vector2(900.0, 450.0)
			}
		}
	}

	var saved := U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})
	assert_true(saved, "Save should succeed")

	var loaded := U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	var input_settings: Dictionary = loaded.get("input_settings", {})
	var touchscreen: Dictionary = input_settings.get("touchscreen_settings", {})
	var button_positions: Dictionary = touchscreen.get("custom_button_positions", {})

	var jump_pos: Variant = button_positions.get("jump")
	assert_true(jump_pos is Vector2, "Loaded jump position should be Vector2")
	assert_almost_eq(jump_pos.x, 800.0, 0.0001)
	assert_almost_eq(jump_pos.y, 450.0, 0.0001)

	var sprint_pos: Variant = button_positions.get("sprint")
	assert_true(sprint_pos is Vector2, "Loaded sprint position should be Vector2")
	assert_almost_eq(sprint_pos.x, 900.0, 0.0001)
	assert_almost_eq(sprint_pos.y, 450.0, 0.0001)

func test_save_and_load_preserves_sentinel_value() -> void:
	var settings := {
		"active_profile_id": "default",
		"touchscreen_settings": {
			"custom_joystick_position": Vector2(-1, -1)
		}
	}

	var saved := U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})
	assert_true(saved, "Save should succeed")

	var loaded := U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	var input_settings: Dictionary = loaded.get("input_settings", {})
	var touchscreen: Dictionary = input_settings.get("touchscreen_settings", {})
	var joystick_pos: Variant = touchscreen.get("custom_joystick_position")

	assert_true(joystick_pos is Vector2, "Sentinel value should remain Vector2")
	assert_eq(joystick_pos, Vector2(-1, -1), "Sentinel value (-1, -1) should be preserved")

func test_json_file_contains_dict_format_not_vector2() -> void:
	var settings := {
		"active_profile_id": "default",
		"touchscreen_settings": {
			"custom_joystick_position": Vector2(100.0, 400.0),
			"custom_button_positions": {
				"jump": Vector2(750.0, 450.0)
			}
		}
	}

	U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})

	# Read raw JSON file
	var file := FileAccess.open("user://global_settings.json", FileAccess.READ)
	assert_not_null(file, "JSON file should exist")

	var json_text := file.get_as_text()
	file = null

	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "JSON should parse to dictionary")

	var input_settings: Dictionary = (parsed as Dictionary).get("input_settings", {})
	var touchscreen: Dictionary = input_settings.get("touchscreen_settings", {})
	var joystick_pos: Variant = touchscreen.get("custom_joystick_position")

	# Verify it's stored as {x, y} dict, NOT Vector2
	assert_true(joystick_pos is Dictionary, "JSON should store position as dict, not Vector2")
	assert_true((joystick_pos as Dictionary).has("x"), "Position dict should have 'x'")
	assert_true((joystick_pos as Dictionary).has("y"), "Position dict should have 'y'")
	assert_almost_eq(float((joystick_pos as Dictionary)["x"]), 100.0, 0.0001)
	assert_almost_eq(float((joystick_pos as Dictionary)["y"]), 400.0, 0.0001)

	var button_positions: Dictionary = touchscreen.get("custom_button_positions", {})
	var jump_pos: Variant = button_positions.get("jump")
	assert_true(jump_pos is Dictionary, "Button position should be dict in JSON")
	assert_almost_eq(float((jump_pos as Dictionary)["x"]), 750.0, 0.0001)
	assert_almost_eq(float((jump_pos as Dictionary)["y"]), 450.0, 0.0001)

func test_load_handles_missing_touchscreen_fields_gracefully() -> void:
	var settings := {
		"active_profile_id": "default",
		"touchscreen_settings": {}
	}

	U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})
	var loaded := U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()

	var input_settings: Dictionary = loaded.get("input_settings", {})
	var touchscreen: Dictionary = input_settings.get("touchscreen_settings", {})
	assert_not_null(touchscreen, "Empty touchscreen_settings should load without error")

func _cleanup_global_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("global_settings.json"):
		dir.remove("global_settings.json")
	if dir.file_exists("global_settings.json.backup"):
		dir.remove("global_settings.json.backup")
