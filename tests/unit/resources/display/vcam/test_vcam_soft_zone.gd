extends GutTest

const SOFT_ZONE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")

func _new_soft_zone() -> Resource:
	return SOFT_ZONE_SCRIPT.new()

func test_dead_zone_width_default_is_point_one() -> void:
	var soft_zone := _new_soft_zone()
	assert_almost_eq(float(soft_zone.get("dead_zone_width")), 0.1, 0.0001)

func test_dead_zone_height_default_is_point_one() -> void:
	var soft_zone := _new_soft_zone()
	assert_almost_eq(float(soft_zone.get("dead_zone_height")), 0.1, 0.0001)

func test_soft_zone_width_default_is_point_four() -> void:
	var soft_zone := _new_soft_zone()
	assert_almost_eq(float(soft_zone.get("soft_zone_width")), 0.4, 0.0001)

func test_soft_zone_height_default_is_point_four() -> void:
	var soft_zone := _new_soft_zone()
	assert_almost_eq(float(soft_zone.get("soft_zone_height")), 0.4, 0.0001)

func test_damping_default_is_two() -> void:
	var soft_zone := _new_soft_zone()
	assert_almost_eq(float(soft_zone.get("damping")), 2.0, 0.0001)

func test_hysteresis_margin_default_is_point_zero_two() -> void:
	var soft_zone := _new_soft_zone()
	assert_almost_eq(float(soft_zone.get("hysteresis_margin")), 0.02, 0.0001)

func test_all_values_are_non_negative() -> void:
	var soft_zone := _new_soft_zone()
	assert_true(float(soft_zone.get("dead_zone_width")) >= 0.0)
	assert_true(float(soft_zone.get("dead_zone_height")) >= 0.0)
	assert_true(float(soft_zone.get("soft_zone_width")) >= 0.0)
	assert_true(float(soft_zone.get("soft_zone_height")) >= 0.0)
	assert_true(float(soft_zone.get("damping")) >= 0.0)
	assert_true(float(soft_zone.get("hysteresis_margin")) >= 0.0)

func test_soft_zone_dimensions_are_not_smaller_than_dead_zone() -> void:
	var soft_zone := _new_soft_zone()
	var dead_width := float(soft_zone.get("dead_zone_width"))
	var dead_height := float(soft_zone.get("dead_zone_height"))
	var soft_width := float(soft_zone.get("soft_zone_width"))
	var soft_height := float(soft_zone.get("soft_zone_height"))
	assert_true(soft_width >= dead_width)
	assert_true(soft_height >= dead_height)
