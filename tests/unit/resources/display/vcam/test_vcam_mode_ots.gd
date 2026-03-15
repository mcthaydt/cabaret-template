extends GutTest

const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const MOVEMENT_SETTINGS_SCRIPT := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const DEFAULT_OTS_PATH := "res://resources/display/vcam/cfg_default_ots.tres"
const DEFAULT_OTS_MOVEMENT_PATH := "res://resources/base_settings/gameplay/cfg_ots_movement_default.tres"

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _resolved(mode: Resource) -> Dictionary:
	var resolved_variant: Variant = mode.call("get_resolved_values")
	if resolved_variant is Dictionary:
		return resolved_variant as Dictionary
	return {}

func test_shoulder_offset_default_matches_ots_baseline() -> void:
	var mode: Resource = _new_mode()
	var shoulder_offset: Vector3 = mode.get("shoulder_offset") as Vector3
	assert_almost_eq(shoulder_offset.x, 0.3, 0.0001)
	assert_almost_eq(shoulder_offset.y, 1.6, 0.0001)
	assert_almost_eq(shoulder_offset.z, -0.5, 0.0001)

func test_camera_distance_default_is_one_point_eight() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("camera_distance")), 1.8, 0.0001)

func test_look_multiplier_default_is_one() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("look_multiplier")), 1.0, 0.0001)

func test_pitch_min_default_is_negative_sixty() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("pitch_min")), -60.0, 0.0001)

func test_pitch_max_default_is_fifty() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("pitch_max")), 50.0, 0.0001)

func test_fov_default_is_sixty() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("fov")), 60.0, 0.0001)

func test_collision_probe_radius_default_is_zero_point_fifteen() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("collision_probe_radius")), 0.15, 0.0001)

func test_fov_resolves_to_valid_range() -> void:
	var mode: Resource = _new_mode()
	mode.set("fov", 0.0)
	var resolved_low: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_low.get("fov", 0.0)), 1.0, 0.0001)

	mode.set("fov", 180.0)
	var resolved_high: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_high.get("fov", 0.0)), 179.0, 0.0001)

func test_look_multiplier_resolves_to_positive_value() -> void:
	var mode: Resource = _new_mode()
	mode.set("look_multiplier", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_true(float(resolved_zero.get("look_multiplier", 0.0)) > 0.0)

	mode.set("look_multiplier", -1.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_true(float(resolved_negative.get("look_multiplier", 0.0)) > 0.0)

func test_pitch_bounds_resolve_when_inverted() -> void:
	var mode: Resource = _new_mode()
	mode.set("pitch_min", 10.0)
	mode.set("pitch_max", -10.0)
	var resolved: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved.get("pitch_min", 0.0)), -10.0, 0.0001)
	assert_almost_eq(float(resolved.get("pitch_max", 0.0)), 10.0, 0.0001)

func test_collision_recovery_speed_default_is_eight() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("collision_recovery_speed")), 8.0, 0.0001)

func test_collision_probe_radius_resolves_non_negative() -> void:
	var mode: Resource = _new_mode()
	mode.set("collision_probe_radius", -0.5)
	var resolved: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved.get("collision_probe_radius", 1.0)), 0.0, 0.0001)

func test_collision_recovery_speed_resolves_to_positive_value() -> void:
	var mode: Resource = _new_mode()
	mode.set("collision_recovery_speed", -3.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_true(float(resolved_negative.get("collision_recovery_speed", 0.0)) > 0.0)

	mode.set("collision_recovery_speed", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_true(float(resolved_zero.get("collision_recovery_speed", 0.0)) > 0.0)

func test_shoulder_sway_defaults_match_expected_values() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("shoulder_sway_angle")), 0.0, 0.0001)
	assert_almost_eq(float(mode.get("shoulder_sway_smoothing")), 6.0, 0.0001)

func test_shoulder_sway_angle_resolves_non_negative() -> void:
	var mode: Resource = _new_mode()
	mode.set("shoulder_sway_angle", -2.0)
	var resolved: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved.get("shoulder_sway_angle", 1.0)), 0.0, 0.0001)

func test_landing_dip_defaults_match_expected_values() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("landing_dip_distance")), 0.0, 0.0001)
	assert_almost_eq(float(mode.get("landing_dip_recovery_speed")), 6.0, 0.0001)

func test_landing_dip_recovery_speed_resolves_to_positive_value() -> void:
	var mode: Resource = _new_mode()
	mode.set("landing_dip_recovery_speed", -2.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_true(float(resolved_negative.get("landing_dip_recovery_speed", 0.0)) > 0.0)

	mode.set("landing_dip_recovery_speed", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_true(float(resolved_zero.get("landing_dip_recovery_speed", 0.0)) > 0.0)

func test_aiming_defaults_match_expected_values() -> void:
	var mode: Resource = _new_mode()
	assert_eq(mode.get("movement_profile"), null)
	assert_true(bool(mode.get("disable_sprint")))
	assert_true(bool(mode.get("lock_facing_to_camera")))
	assert_almost_eq(float(mode.get("aim_blend_duration")), 0.15, 0.0001)

func test_aim_blend_duration_resolves_to_positive_minimum() -> void:
	var mode: Resource = _new_mode()
	mode.set("aim_blend_duration", -1.0)
	var resolved_negative: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_negative.get("aim_blend_duration", 0.0)), 0.01, 0.0001)

	mode.set("aim_blend_duration", 0.0)
	var resolved_zero: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_zero.get("aim_blend_duration", 0.0)), 0.01, 0.0001)

func test_aiming_bool_flags_passthrough_through_resolved_values() -> void:
	var mode: Resource = _new_mode()
	mode.set("disable_sprint", false)
	mode.set("lock_facing_to_camera", false)
	var resolved: Dictionary = _resolved(mode)
	assert_false(bool(resolved.get("disable_sprint", true)))
	assert_false(bool(resolved.get("lock_facing_to_camera", true)))

func test_movement_profile_passthrough_through_resolved_values() -> void:
	var mode: Resource = _new_mode()
	var movement_profile := MOVEMENT_SETTINGS_SCRIPT.new()
	mode.set("movement_profile", movement_profile)
	var resolved: Dictionary = _resolved(mode)
	assert_eq(resolved.get("movement_profile", null), movement_profile)

func test_default_ots_preset_loads_as_ots_mode() -> void:
	var preset := load(DEFAULT_OTS_PATH) as Resource
	assert_not_null(preset, "Default OTS preset should load")
	assert_true(preset.get_script() == MODE_SCRIPT, "Default OTS preset should use RS_VCamModeOTS")

func test_default_ots_movement_profile_preset_loads_with_expected_values() -> void:
	var movement_profile := load(DEFAULT_OTS_MOVEMENT_PATH) as Resource
	assert_not_null(movement_profile, "Default OTS movement preset should load")
	assert_true(
		movement_profile.get_script() == MOVEMENT_SETTINGS_SCRIPT,
		"Default OTS movement preset should use RS_MovementSettings"
	)
	assert_almost_eq(float(movement_profile.get("max_speed")), 3.0, 0.0001)
	assert_almost_eq(float(movement_profile.get("sprint_speed_multiplier")), 1.0, 0.0001)
	assert_almost_eq(float(movement_profile.get("slope_limit_degrees")), 50.0, 0.0001)

func test_default_ots_preset_references_ots_movement_profile() -> void:
	var preset := load(DEFAULT_OTS_PATH) as Resource
	assert_not_null(preset, "Default OTS preset should load")
	var movement_profile: Resource = preset.get("movement_profile") as Resource
	assert_not_null(movement_profile, "Default OTS preset should reference movement profile")
	assert_true(
		movement_profile.get_script() == MOVEMENT_SETTINGS_SCRIPT,
		"Default OTS movement profile should use RS_MovementSettings"
	)
