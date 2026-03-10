extends GutTest

const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

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
