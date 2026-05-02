extends BaseTest

const CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")

func _make_curve(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	for point in points:
		curve.add_point(point, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve

func test_response_curve_linear_passthrough_keeps_raw_score() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.35
	condition.response_curve = _make_curve([Vector2(0.0, 0.0), Vector2(1.0, 1.0)])

	var score: float = condition.evaluate({})
	assert_almost_eq(score, 0.35, 0.01)

func test_response_curve_sigmoid_shape_remaps_mid_range_values() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.5
	condition.response_curve = _make_curve([
		Vector2(0.0, 0.0),
		Vector2(0.25, 0.1),
		Vector2(0.5, 0.75),
		Vector2(0.75, 0.95),
		Vector2(1.0, 1.0)
	])

	var score: float = condition.evaluate({})
	assert_gt(score, 0.6)
	assert_lt(score, 0.9)

func test_invert_flag_flips_score() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.7
	condition.invert = true

	var score: float = condition.evaluate({})
	assert_almost_eq(score, 0.3, 0.01)

func test_response_curve_applied_before_invert() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.25
	condition.response_curve = _make_curve([Vector2(0.0, 0.8), Vector2(1.0, 0.8)])
	condition.invert = true

	var score: float = condition.evaluate({})
	assert_almost_eq(score, 0.2, 0.02)

func test_null_response_curve_passes_score_through() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.42
	condition.response_curve = null

	var score: float = condition.evaluate({})
	assert_almost_eq(score, 0.42, 0.0001)
