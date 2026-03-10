extends GutTest

const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _resolved(mode: Resource) -> Dictionary:
	var resolved_variant: Variant = mode.call("get_resolved_values")
	if resolved_variant is Dictionary:
		return resolved_variant as Dictionary
	return {}

func test_distance_default_is_five() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("distance")), 5.0, 0.0001)

func test_authored_pitch_default_is_negative_twenty() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("authored_pitch")), -20.0, 0.0001)

func test_authored_yaw_default_is_zero() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("authored_yaw")), 0.0, 0.0001)

func test_allow_player_rotation_default_is_true() -> void:
	var mode: Resource = _new_mode()
	assert_true(bool(mode.get("allow_player_rotation")))

func test_rotation_speed_default_is_two() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("rotation_speed")), 2.0, 0.0001)

func test_fov_default_is_seventy_five() -> void:
	var mode: Resource = _new_mode()
	assert_almost_eq(float(mode.get("fov")), 75.0, 0.0001)

func test_distance_default_is_positive() -> void:
	var mode: Resource = _new_mode()
	assert_true(float(mode.get("distance")) > 0.0)

func test_fov_default_is_within_valid_range() -> void:
	var mode: Resource = _new_mode()
	var fov: float = float(mode.get("fov"))
	assert_true(fov >= 1.0)
	assert_true(fov <= 179.0)

func test_fov_resolves_to_valid_range() -> void:
	var mode: Resource = _new_mode()
	mode.set("fov", 0.0)
	var resolved_low: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_low.get("fov", 0.0)), 1.0, 0.0001)

	mode.set("fov", 180.0)
	var resolved_high: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved_high.get("fov", 0.0)), 179.0, 0.0001)

func test_distance_resolves_non_negative() -> void:
	var mode: Resource = _new_mode()
	mode.set("distance", -2.0)
	var resolved: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved.get("distance", 1.0)), 0.0, 0.0001)

func test_non_finite_values_resolve_deterministically() -> void:
	var mode: Resource = _new_mode()
	mode.set("distance", INF)
	mode.set("fov", INF)
	mode.set("authored_pitch", INF)
	mode.set("authored_yaw", INF)
	mode.set("rotation_speed", INF)
	var resolved: Dictionary = _resolved(mode)
	assert_almost_eq(float(resolved.get("distance", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("fov", 0.0)), 75.0, 0.0001)
	assert_almost_eq(float(resolved.get("authored_pitch", 0.0)), -20.0, 0.0001)
	assert_almost_eq(float(resolved.get("authored_yaw", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("rotation_speed", -1.0)), 0.0, 0.0001)
