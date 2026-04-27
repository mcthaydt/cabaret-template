extends RefCounted

func build() -> Dictionary:
	var profiles: Dictionary = {}

	var kb: RefCounted = load("res://scripts/core/resources/input/profiles/rs_default_keyboard_profile.gd").new()
	profiles["default"] = kb.build()

	var alt: RefCounted = load("res://scripts/core/resources/input/profiles/rs_alternate_keyboard_profile.gd").new()
	profiles["alternate"] = alt.build()

	var acc: RefCounted = load("res://scripts/core/resources/input/profiles/rs_accessibility_keyboard_profile.gd").new()
	profiles["accessibility"] = acc.build()

	var gp: RefCounted = load("res://scripts/core/resources/input/profiles/rs_default_gamepad_profile.gd").new()
	profiles["default_gamepad"] = gp.build()

	var agp: RefCounted = load("res://scripts/core/resources/input/profiles/rs_accessibility_gamepad_profile.gd").new()
	profiles["accessibility_gamepad"] = agp.build()

	var ts: RefCounted = load("res://scripts/core/resources/input/profiles/rs_default_touchscreen_profile.gd").new()
	profiles["default_touchscreen"] = ts.build()

	return profiles
