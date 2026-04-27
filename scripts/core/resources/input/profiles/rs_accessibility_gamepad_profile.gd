extends RefCounted

static func build() -> RS_InputProfile:
	return U_InputProfileBuilder.new().
		named("input.profile.accessibility_gamepad.name").
		with_device_type(1).
		with_description("input.profile.accessibility_gamepad.description").
		bind_joypad_motion("move_forward", JOY_AXIS_LEFT_Y, -1.0).
		bind_joypad_motion("move_backward", JOY_AXIS_LEFT_Y, 1.0).
		bind_joypad_motion("move_left", JOY_AXIS_LEFT_X, -1.0).
		bind_joypad_motion("move_right", JOY_AXIS_LEFT_X, 1.0).
		bind_joypad_button("jump", JOY_BUTTON_A).
		bind_joypad_button("sprint", JOY_BUTTON_LEFT_STICK).
		bind_joypad_button("interact", JOY_BUTTON_X).
		bind_joypad_button("camera_center", JOY_BUTTON_RIGHT_STICK).
		bind_joypad_button("ui_up", JOY_BUTTON_DPAD_UP).
		bind_joypad_button("ui_down", JOY_BUTTON_DPAD_DOWN).
		bind_joypad_button("ui_left", JOY_BUTTON_DPAD_LEFT).
		bind_joypad_button("ui_right", JOY_BUTTON_DPAD_RIGHT).
		bind_joypad_motion("look_up", JOY_AXIS_RIGHT_Y, -1.0).
		bind_joypad_motion("look_down", JOY_AXIS_RIGHT_Y, 1.0).
		bind_joypad_motion("look_left", JOY_AXIS_RIGHT_X, -1.0).
		bind_joypad_motion("look_right", JOY_AXIS_RIGHT_X, 1.0).
		with_accessibility(0.2, true, 0.0).
		build()
