extends GutTest

const RS_InputProfile = preload("res://scripts/resources/input/rs_input_profile.gd")

func test_defaults_and_setters() -> void:
	var p := RS_InputProfile.new()
	assert_eq(p.profile_name, "Default", "Default profile name")
	assert_eq(p.device_type, 0, "Default device type is Keyboard/Mouse")
	assert_true(p.is_system_profile, "Default is system profile")

	var jump_event := InputEventKey.new()
	jump_event.physical_keycode = KEY_SPACE
	p.set_events_for_action(StringName("jump"), [jump_event])

	var events := p.get_events_for_action(StringName("jump"))
	assert_eq(events.size(), 1, "One jump binding present")
	assert_true(events[0] is InputEventKey, "Jump mapping is key event")

	# Ensure defensive copy (mutating returned array does not affect profile)
	events.clear()
	var events_after := p.get_events_for_action(StringName("jump"))
	assert_eq(events_after.size(), 1, "Internal events are not aliased")

func test_serialize_to_and_from_dictionary() -> void:
	var p := RS_InputProfile.new()
	p.profile_name = "Unit Test Profile"
	p.device_type = 0
	p.description = "Test profile for RS_InputProfile serialization"
	p.is_system_profile = false

	var move_left := InputEventKey.new()
	move_left.physical_keycode = KEY_A
	var move_right := InputEventKey.new()
	move_right.physical_keycode = KEY_D
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT

	p.set_events_for_action(StringName("move_left"), [move_left])
	p.set_events_for_action(StringName("move_right"), [move_right])
	p.set_events_for_action(StringName("interact"), [mouse_button])

	var data := p.to_dictionary()
	assert_has(data, "action_mappings", "Dictionary contains mappings")

	var p2 := RS_InputProfile.new()
	p2.from_dictionary(data)
	assert_eq(p2.profile_name, p.profile_name, "Profile name round-trip")
	assert_eq(p2.device_type, p.device_type, "Device type round-trip")
	assert_eq(p2.description, p.description, "Description round-trip")
	assert_eq(p2.is_system_profile, p.is_system_profile, "System flag round-trip")

	var ml := p2.get_events_for_action(StringName("move_left"))
	assert_eq(ml.size(), 1, "move_left restored")
	assert_true(ml[0] is InputEventKey, "move_left is key event")

	var intr := p2.get_events_for_action(StringName("interact"))
	assert_eq(intr.size(), 1, "interact restored")
	assert_true(intr[0] is InputEventMouseButton, "interact is mouse button")

func test_touchscreen_fields_serialize_roundtrip() -> void:
	var p := RS_InputProfile.new()
	p.profile_name = "Touchscreen Test Profile"
	p.device_type = 2  # Touchscreen

	# Set touchscreen fields
	p.virtual_joystick_position = Vector2(120, 450)
	p.virtual_buttons = [
		{"action": StringName("jump"), "position": Vector2(800, 450)},
		{"action": StringName("sprint"), "position": Vector2(800, 350)},
		{"action": StringName("interact"), "position": Vector2(700, 450)},
		{"action": StringName("pause"), "position": Vector2(700, 350)}
	]

	# Serialize to dictionary
	var data := p.to_dictionary()
	assert_has(data, "virtual_joystick_position", "Dictionary contains virtual_joystick_position")
	assert_has(data, "virtual_buttons", "Dictionary contains virtual_buttons")

	# Deserialize to new profile
	var p2 := RS_InputProfile.new()
	p2.from_dictionary(data)

	# Verify touchscreen fields were restored
	assert_eq(p2.virtual_joystick_position, Vector2(120, 450), "virtual_joystick_position round-trip")
	assert_eq(p2.virtual_buttons.size(), 4, "virtual_buttons array size restored")

	# Verify button data
	assert_eq(p2.virtual_buttons[0]["action"], StringName("jump"), "Button 0 action restored")
	assert_eq(p2.virtual_buttons[0]["position"], Vector2(800, 450), "Button 0 position restored")
	assert_eq(p2.virtual_buttons[1]["action"], StringName("sprint"), "Button 1 action restored")
	assert_eq(p2.virtual_buttons[1]["position"], Vector2(800, 350), "Button 1 position restored")

func test_touchscreen_profile_loads_with_virtual_buttons() -> void:
	var profile: RS_InputProfile = load("res://resources/input/profiles/default_touchscreen.tres")
	assert_not_null(profile, "Touchscreen profile should load")
	assert_eq(profile.device_type, 2, "Device type should be touchscreen")
	assert_eq(profile.virtual_buttons.size(), 4, "Should have 4 virtual buttons")
	# Test button structure
	for button in profile.virtual_buttons:
		assert_true(button.has("action"), "Button should have action")
		assert_true(button.has("position"), "Button should have position")

func test_touchscreen_profile_has_joystick_position() -> void:
	var profile: RS_InputProfile = load("res://resources/input/profiles/default_touchscreen.tres")
	assert_ne(profile.virtual_joystick_position, Vector2(-1, -1), "Should have joystick position")

## Test that default keyboard profiles use physical_keycode (not keycode)
## This ensures keyboard input works correctly with Godot's input system
func test_default_keyboard_profiles_use_physical_keycode() -> void:
	var profiles := [
		"res://resources/input/profiles/default_keyboard.tres",
		"res://resources/input/profiles/alternate_keyboard.tres",
		"res://resources/input/profiles/accessibility_keyboard.tres"
	]

	for profile_path in profiles:
		var profile: RS_InputProfile = load(profile_path)
		assert_not_null(profile, "Profile loaded: %s" % profile_path)

		# Check all action mappings
		for action_name in profile.action_mappings.keys():
			var events: Array = profile.get_events_for_action(StringName(action_name))
			for event in events:
				if event is InputEventKey:
					var key_event := event as InputEventKey
					assert_ne(key_event.physical_keycode, 0,
						"Profile %s action '%s' uses physical_keycode (not keycode)" % [profile_path, action_name])
					# If keycode is set but physical_keycode is 0, that's the bug we fixed
					if key_event.keycode != 0 and key_event.physical_keycode == 0:
						fail_test("Profile %s action '%s' has keycode=%d but physical_keycode=0 (should use physical_keycode)" %
							[profile_path, action_name, key_event.keycode])
