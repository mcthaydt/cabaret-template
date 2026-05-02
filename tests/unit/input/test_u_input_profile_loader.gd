extends GutTest

var _loader: U_InputProfileLoader
var _test_action: StringName = &"_test_loader_action"

func before_each() -> void:
	_loader = U_InputProfileLoader.new()

func after_each() -> void:
	_loader = null
	if InputMap.has_action(_test_action):
		InputMap.erase_action(_test_action)

func test_load_available_profiles_returns_all_six_profiles() -> void:
	var profiles: Dictionary = _loader.load_available_profiles()
	assert_eq(profiles.size(), 6, "Expected 6 profiles from manifest")
	assert_true(profiles.has("default"), "Must include 'default' keyboard profile")
	assert_true(profiles.has("alternate"), "Must include 'alternate' keyboard profile")
	assert_true(profiles.has("accessibility"), "Must include 'accessibility' keyboard profile")
	assert_true(profiles.has("default_gamepad"), "Must include 'default_gamepad' profile")
	assert_true(profiles.has("accessibility_gamepad"), "Must include 'accessibility_gamepad' profile")
	assert_true(profiles.has("default_touchscreen"), "Must include 'default_touchscreen' profile")

func test_load_available_profiles_values_are_rs_input_profile() -> void:
	var profiles: Dictionary = _loader.load_available_profiles()
	for key in profiles.keys():
		var profile: Variant = profiles[key]
		assert_true(profile is RS_InputProfile, "Profile '%s' should be RS_InputProfile" % key)

func test_load_profile_returns_rs_input_profile_for_valid_id() -> void:
	var profiles: Dictionary = _loader.load_available_profiles()
	var profile: RS_InputProfile = _loader.load_profile(profiles, "default")
	assert_not_null(profile, "load_profile('default') should return non-null")
	assert_true(profile is RS_InputProfile, "Result should be RS_InputProfile")

func test_load_profile_returns_null_for_missing_id() -> void:
	var profiles: Dictionary = _loader.load_available_profiles()
	var profile: RS_InputProfile = _loader.load_profile(profiles, "nonexistent_profile_id")
	assert_null(profile, "load_profile with missing id should return null")
	assert_push_error("Input profile not found")

func test_apply_profile_null_does_not_crash() -> void:
	_loader.apply_profile_to_input_map(null)
	assert_true(true, "apply_profile_to_input_map(null) should return without error")

func test_apply_profile_adds_keyboard_event_to_input_map() -> void:
	var profile: RS_InputProfile = (
		U_InputProfileBuilder.new()
		.bind_key(_test_action, KEY_Z)
		.build()
	)
	_loader.apply_profile_to_input_map(profile)
	assert_true(InputMap.has_action(_test_action), "Action should be added to InputMap")
	var events: Array = InputMap.action_get_events(_test_action)
	var has_key_z := false
	for ev: Variant in events:
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_Z:
			has_key_z = true
	assert_true(has_key_z, "InputMap should contain KEY_Z event for test action")

func test_apply_profile_preserves_other_device_type_events() -> void:
	# Pre-add a keyboard event for the test action
	InputMap.add_action(_test_action)
	var kb_event := InputEventKey.new()
	kb_event.physical_keycode = KEY_Q
	InputMap.action_add_event(_test_action, kb_event)

	# Apply a gamepad profile that also binds the same action
	var gamepad_profile: RS_InputProfile = (
		U_InputProfileBuilder.new()
		.with_device_type(1)
		.bind_joypad_button(_test_action, JOY_BUTTON_B)
		.build()
	)
	_loader.apply_profile_to_input_map(gamepad_profile)

	var events: Array = InputMap.action_get_events(_test_action)
	var has_keyboard := false
	var has_joypad := false
	for ev: Variant in events:
		if ev is InputEventKey:
			has_keyboard = true
		if ev is InputEventJoypadButton:
			has_joypad = true
	assert_true(has_keyboard, "Keyboard event should be preserved when applying gamepad profile")
	assert_true(has_joypad, "Joypad event should be added when applying gamepad profile")

func test_apply_profile_replaces_same_device_type_events() -> void:
	# Pre-add a keyboard event
	InputMap.add_action(_test_action)
	var old_event := InputEventKey.new()
	old_event.physical_keycode = KEY_Q
	InputMap.action_add_event(_test_action, old_event)

	# Apply keyboard profile that binds same action to a different key
	var kb_profile: RS_InputProfile = (
		U_InputProfileBuilder.new()
		.with_device_type(0)
		.bind_key(_test_action, KEY_Z)
		.build()
	)
	_loader.apply_profile_to_input_map(kb_profile)

	var events: Array = InputMap.action_get_events(_test_action)
	var has_old_key := false
	var has_new_key := false
	for ev: Variant in events:
		if ev is InputEventKey:
			var ke := ev as InputEventKey
			if ke.physical_keycode == KEY_Q:
				has_old_key = true
			if ke.physical_keycode == KEY_Z:
				has_new_key = true
	assert_false(has_old_key, "Old keyboard event should be replaced by new profile")
	assert_true(has_new_key, "New keyboard event from profile should be present")
