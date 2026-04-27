extends RefCounted

static func build() -> RS_InputProfile:
	return U_InputProfileBuilder.new().
		named("input.profile.alternate_keyboard.name").
		with_description("input.profile.alternate_keyboard.description").
		bind_key("move_forward", KEY_UP).
		bind_key("move_backward", KEY_DOWN).
		bind_key("move_left", KEY_LEFT).
		bind_key("move_right", KEY_RIGHT).
		bind_key("jump", KEY_SPACE).
		bind_key("sprint", KEY_SHIFT).
		bind_key("interact", KEY_E).
		bind_key("camera_center", KEY_C).
		bind_key("look_up", KEY_W).
		bind_key("look_down", KEY_S).
		bind_key("look_left", KEY_A).
		bind_key("look_right", KEY_D).
		bind_key("ui_up", KEY_W).
		bind_key("ui_down", KEY_S).
		bind_key("ui_left", KEY_A).
		bind_key("ui_right", KEY_D).
		build()
