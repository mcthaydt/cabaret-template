extends GutTest


func test_defaults_are_stable() -> void:
	var config := RS_CharacterLightZoneConfig.new()
	assert_eq(config.shape_type, RS_CharacterLightZoneConfig.ShapeType.BOX)
	assert_eq(config.zone_id, StringName(""))
	assert_eq(config.local_offset, Vector3.ZERO)
	assert_eq(config.box_size, Vector3(4.0, 3.0, 4.0))
	assert_almost_eq(config.cylinder_radius, 2.0, 0.0001)
	assert_almost_eq(config.cylinder_height, 3.0, 0.0001)
	assert_almost_eq(config.falloff, 0.5, 0.0001)
	assert_almost_eq(config.blend_weight, 1.0, 0.0001)
	assert_eq(config.priority, 0)

func test_profile_assignment_rejects_incompatible_resource() -> void:
	var config := RS_CharacterLightZoneConfig.new()
	var profile := RS_CharacterLightingProfile.new()
	config.profile = profile
	assert_eq(config.profile, profile)

	var incompatible := Resource.new()
	config.profile = incompatible
	assert_eq(config.profile, profile, "Profile should remain unchanged when assigned incompatible resource")

func test_get_resolved_values_clamps_dimensions_and_blend_inputs() -> void:
	var config := RS_CharacterLightZoneConfig.new()
	var profile := RS_CharacterLightingProfile.new()
	profile.intensity = 99.0
	profile.blend_smoothing = -10.0

	config.profile = profile
	config.box_size = Vector3(-1.0, 0.0, 2.0)
	config.cylinder_radius = -5.0
	config.cylinder_height = 0.0
	config.falloff = -3.0
	config.blend_weight = 9.0

	var resolved: Dictionary = config.get_resolved_values()
	assert_eq(resolved.get("box_size"), Vector3(0.01, 0.01, 2.0))
	assert_almost_eq(float(resolved.get("cylinder_radius", -1.0)), 0.01, 0.0001)
	assert_almost_eq(float(resolved.get("cylinder_height", -1.0)), 0.01, 0.0001)
	assert_almost_eq(float(resolved.get("falloff", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("blend_weight", -1.0)), 1.0, 0.0001)

	var profile_snapshot: Dictionary = resolved.get("profile", {})
	assert_almost_eq(float(profile_snapshot.get("intensity", -1.0)), 8.0, 0.0001)
	assert_almost_eq(float(profile_snapshot.get("blend_smoothing", -1.0)), 0.0, 0.0001)

func test_get_resolved_values_returns_deep_copied_profile_snapshot() -> void:
	var config := RS_CharacterLightZoneConfig.new()
	var profile := RS_CharacterLightingProfile.new()
	config.profile = profile

	var first: Dictionary = config.get_resolved_values()
	var first_profile: Dictionary = first.get("profile", {})
	first_profile["intensity"] = 0.0

	var second: Dictionary = config.get_resolved_values()
	var second_profile: Dictionary = second.get("profile", {})
	assert_almost_eq(float(second_profile.get("intensity", -1.0)), 1.0, 0.0001)
