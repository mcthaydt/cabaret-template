extends GutTest


func test_defaults_are_stable() -> void:
	var profile := RS_CharacterLightingProfile.new()
	assert_eq(profile.profile_id, StringName(""))
	assert_eq(profile.tint, Color(1.0, 1.0, 1.0, 1.0))
	assert_almost_eq(profile.intensity, 1.0, 0.0001)
	assert_almost_eq(profile.blend_smoothing, 0.15, 0.0001)

func test_get_resolved_values_clamps_intensity_and_smoothing() -> void:
	var profile := RS_CharacterLightingProfile.new()
	profile.tint = Color(0.9, 0.2, 0.1, 0.8)
	profile.intensity = -3.0
	profile.blend_smoothing = 9.0

	var resolved: Dictionary = profile.get_resolved_values()
	assert_eq(resolved.get("tint"), Color(0.9, 0.2, 0.1, 0.8))
	assert_almost_eq(float(resolved.get("intensity", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("blend_smoothing", -1.0)), 1.0, 0.0001)

func test_get_resolved_values_returns_fresh_dictionary_instances() -> void:
	var profile := RS_CharacterLightingProfile.new()
	var first: Dictionary = profile.get_resolved_values()
	first["intensity"] = 99.0

	var second: Dictionary = profile.get_resolved_values()
	assert_almost_eq(float(second.get("intensity", -1.0)), 1.0, 0.0001)
