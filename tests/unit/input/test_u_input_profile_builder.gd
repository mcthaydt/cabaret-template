extends GutTest

const RS_InputProfile = preload("res://scripts/core/resources/input/rs_input_profile.gd")
const U_InputProfileBuilder = preload("res://scripts/core/utils/input/u_input_profile_builder.gd")

func test_builder_creates_profile_with_defaults() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.build()
	assert_not_null(profile, "build() should return a profile")
	assert_eq(profile.profile_name, "Default", "Default profile_name")
	assert_eq(profile.device_type, 0, "Default device_type is keyboard")
	assert_true(profile.is_system_profile, "Default is_system_profile is true")

func test_builder_chains_and_sets_name() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.named("Test Profile").build()
	assert_eq(profile.profile_name, "Test Profile", "Named sets profile_name")

func test_builder_sets_device_type() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.with_device_type(1).build()
	assert_eq(profile.device_type, 1, "with_device_type sets gamepad")

func test_builder_sets_description() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.with_description("A test profile").build()
	assert_eq(profile.description, "A test profile")

func test_builder_sets_system_profile() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.with_system_profile(false).build()
	assert_false(profile.is_system_profile)

func test_builder_binds_key_event() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.bind_key(StringName("jump"), KEY_SPACE).build()
	var events := profile.get_events_for_action(StringName("jump"))
	assert_eq(events.size(), 1, "One event bound")
	assert_true(events[0] is InputEventKey, "Bound event is key")

func test_builder_binds_multiple_actions() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.bind_key("move_forward", KEY_W).bind_key("move_left", KEY_A).bind_key("move_backward", KEY_S).bind_key("move_right", KEY_D).build()
	assert_eq(profile.get_events_for_action("move_forward").size(), 1)
	assert_eq(profile.get_events_for_action("move_left").size(), 1)
	assert_eq(profile.get_events_for_action("move_backward").size(), 1)
	assert_eq(profile.get_events_for_action("move_right").size(), 1)

func test_builder_binds_joypad_button() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.bind_joypad_button("jump", JOY_BUTTON_A).build()
	var events := profile.get_events_for_action("jump")
	assert_eq(events.size(), 1)
	assert_true(events[0] is InputEventJoypadButton)

func test_builder_binds_joypad_motion() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.bind_joypad_motion("look_right", JOY_AXIS_RIGHT_X, 1.0).build()
	var events := profile.get_events_for_action("look_right")
	assert_eq(events.size(), 1)
	assert_true(events[0] is InputEventJoypadMotion)

func test_builder_sets_virtual_joystick_position() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.with_virtual_joystick_position(Vector2(100, 200)).build()
	assert_eq(profile.virtual_joystick_position, Vector2(100, 200))

func test_builder_adds_virtual_button() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.with_virtual_button("jump", Vector2(800, 450)).with_virtual_button("interact", Vector2(700, 450)).build()
	assert_eq(profile.virtual_buttons.size(), 2)
	assert_eq(profile.virtual_buttons[0]["action"], "jump")
	assert_eq(profile.virtual_buttons[0]["position"], Vector2(800, 450))
	assert_eq(profile.virtual_buttons[1]["action"], "interact")
	assert_eq(profile.virtual_buttons[1]["position"], Vector2(700, 450))

func test_builder_sets_accessibility_options() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.with_accessibility(0.25, true, 1.5).build()
	assert_eq(profile.jump_buffer_time, 0.25)
	assert_true(profile.sprint_toggle_mode)
	assert_eq(profile.interact_hold_duration, 1.5)

func test_builder_creates_keyboard_profile_like_tres() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.named("input.profile.default_keyboard.name").with_description("input.profile.default_keyboard.description").bind_key("move_forward", KEY_W).bind_key("move_backward", KEY_S).bind_key("move_left", KEY_A).bind_key("move_right", KEY_D).bind_key("jump", KEY_SPACE).bind_key("sprint", KEY_SHIFT).bind_key("interact", KEY_E).bind_key("camera_center", KEY_C).bind_key("ui_up", KEY_UP).bind_key("ui_down", KEY_DOWN).bind_key("ui_left", KEY_LEFT).bind_key("ui_right", KEY_RIGHT).build()
	assert_eq(profile.profile_name, "input.profile.default_keyboard.name")
	assert_eq(profile.device_type, 0)
	assert_eq(profile.action_mappings.size(), 12)
	var jump_events := profile.get_events_for_action("jump")
	assert_eq(jump_events.size(), 1)

func test_builder_creates_gamepad_profile_like_tres() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.named("input.profile.default_gamepad.name").with_device_type(1).with_description("input.profile.default_gamepad.description").bind_joypad_motion("move_forward", JOY_AXIS_LEFT_Y, -1.0).bind_joypad_motion("move_backward", JOY_AXIS_LEFT_Y, 1.0).bind_joypad_motion("move_left", JOY_AXIS_LEFT_X, -1.0).bind_joypad_motion("move_right", JOY_AXIS_LEFT_X, 1.0).bind_joypad_button("jump", JOY_BUTTON_A).bind_joypad_button("sprint", JOY_BUTTON_LEFT_SHOULDER).bind_joypad_button("interact", JOY_BUTTON_X).bind_joypad_button("camera_center", JOY_BUTTON_RIGHT_STICK).bind_joypad_button("ui_up", JOY_BUTTON_DPAD_UP).bind_joypad_button("ui_down", JOY_BUTTON_DPAD_DOWN).bind_joypad_button("ui_left", JOY_BUTTON_DPAD_LEFT).bind_joypad_button("ui_right", JOY_BUTTON_DPAD_RIGHT).bind_joypad_motion("look_up", JOY_AXIS_RIGHT_Y, -1.0).bind_joypad_motion("look_down", JOY_AXIS_RIGHT_Y, 1.0).bind_joypad_motion("look_left", JOY_AXIS_RIGHT_X, -1.0).bind_joypad_motion("look_right", JOY_AXIS_RIGHT_X, 1.0).build()
	assert_eq(profile.device_type, 1)
	assert_eq(profile.get_events_for_action("jump").size(), 1)

func test_builder_creates_touchscreen_profile_like_tres() -> void:
	var builder := U_InputProfileBuilder.new()
	var profile: RS_InputProfile = builder.named("input.profile.default_touchscreen.name").with_device_type(2).with_description("input.profile.default_touchscreen.description").with_virtual_joystick_position(Vector2(82, 390)).with_virtual_button("interact", Vector2(240, 331)).with_virtual_button("jump", Vector2(787, 373)).with_virtual_button("pause", Vector2(790, 73)).with_virtual_button("sprint", Vector2(715, 433)).build()
	assert_eq(profile.device_type, 2)
	assert_eq(profile.virtual_joystick_position, Vector2(82, 390))
	assert_eq(profile.virtual_buttons.size(), 4)
	assert_eq(profile.virtual_buttons[0]["action"], "interact")
