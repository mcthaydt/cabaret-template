extends RefCounted

static func build() -> RS_InputProfile:
	var builder := U_InputProfileBuilder.new()
	builder.named("input.profile.default_touchscreen.name")
	builder.with_device_type(2)
	builder.with_description("input.profile.default_touchscreen.description")
	builder.with_virtual_joystick_position(Vector2(82, 390))
	builder.with_virtual_button("interact", Vector2(240, 331))
	builder.with_virtual_button("jump", Vector2(787, 373))
	builder.with_virtual_button("pause", Vector2(790, 73))
	builder.with_virtual_button("sprint", Vector2(715, 433))
	return builder.build()
