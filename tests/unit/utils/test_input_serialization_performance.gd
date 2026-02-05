extends GutTest

const U_GLOBAL_SETTINGS_SERIALIZATION := preload("res://scripts/utils/u_global_settings_serialization.gd")
const U_InputRebindUtils := preload("res://scripts/utils/input/u_input_rebind_utils.gd")

func before_each() -> void:
	_cleanup_input_settings_files()

func after_each() -> void:
	_cleanup_input_settings_files()

func test_save_operation_completes_under_100ms() -> void:
	var settings := _make_large_settings_dataset()
	var start := Time.get_ticks_msec()
	var success := U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})
	var elapsed := Time.get_ticks_msec() - start
	assert_true(success, "Save should succeed")
	assert_true(elapsed <= 100, "Expected save < 100ms, took %sms" % elapsed)

func test_load_operation_completes_under_100ms() -> void:
	var settings := _make_large_settings_dataset()
	var save_success := U_GLOBAL_SETTINGS_SERIALIZATION.save_settings({"input_settings": settings})
	assert_true(save_success, "Precondition save should succeed")

	var start := Time.get_ticks_msec()
	var loaded := U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	var elapsed := Time.get_ticks_msec() - start
	assert_true(loaded is Dictionary, "Load should return dictionary")
	assert_true(elapsed <= 100, "Expected load < 100ms, took %sms" % elapsed)

func _make_large_settings_dataset(action_count: int = 24) -> Dictionary:
	var custom: Dictionary = {}
	for i in range(action_count):
		var events: Array = []

		var key_event := InputEventKey.new()
		key_event.keycode = Key.KEY_A + (i % 26)
		key_event.physical_keycode = key_event.keycode
		events.append(U_InputRebindUtils.event_to_dict(key_event))

		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = (i % 5) + 1
		mouse_event.pressed = true
		events.append(U_InputRebindUtils.event_to_dict(mouse_event))

		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = i % 8
		joy_event.pressed = true
		events.append(U_InputRebindUtils.event_to_dict(joy_event))

		custom["action_%s" % i] = events

	return {
		"active_profile_id": "default",
		"custom_bindings": custom,
		"gamepad_settings": {
			"left_stick_deadzone": 0.25,
			"right_stick_deadzone": 0.2,
			"trigger_deadzone": 0.15,
			"vibration_enabled": true,
			"vibration_intensity": 0.85,
			"invert_y_axis": false
		},
		"mouse_settings": {
			"sensitivity": 1.5,
			"invert_y_axis": false
		},
		"touchscreen_settings": {
			"virtual_joystick_size": 1.0,
			"virtual_joystick_opacity": 0.75,
			"button_layout": "default",
			"button_size": 1.0
		},
		"accessibility": {
			"jump_buffer_time": 0.12,
			"sprint_toggle_mode": false,
			"interact_hold_duration": 0.1
		}
	}

func _cleanup_input_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("global_settings.json"):
		dir.remove("global_settings.json")
	if dir.file_exists("global_settings.json.backup"):
		dir.remove("global_settings.json.backup")
