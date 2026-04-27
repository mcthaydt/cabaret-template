extends RefCounted

static func build() -> RS_InputProfile:
	return U_InputProfileBuilder.new().
		named("input.profile.default_touchscreen.name").
		with_device_type(2).
		with_description("input.profile.default_touchscreen.description").
		with_virtual_joystick_position(Vector2(82, 390)).
		with_virtual_button("interact", Vector2(240, 331)).
		with_virtual_button("jump", Vector2(787, 373)).
		with_virtual_button("pause", Vector2(790, 73)).
		with_virtual_button("sprint", Vector2(715, 433)).
		build()
