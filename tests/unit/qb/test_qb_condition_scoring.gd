extends BaseTest

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_RULE_EVALUATOR := preload("res://scripts/utils/qb/u_qb_rule_evaluator.gd")


func _make_condition_with_curve(
	operator: int,
	value_type: int,
	value: Variant,
	curve: Curve,
	normalize_min: float = 0.0,
	normalize_max: float = 1.0
) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.operator = operator
	condition.value_type = value_type
	condition.score_curve = curve
	condition.normalize_min = normalize_min
	condition.normalize_max = normalize_max

	match value_type:
		QB_CONDITION.ValueType.FLOAT:
			condition.value_float = float(value)
		QB_CONDITION.ValueType.INT:
			condition.value_int = int(value)
		QB_CONDITION.ValueType.STRING:
			condition.value_string = String(value)
		QB_CONDITION.ValueType.BOOL:
			condition.value_bool = bool(value)
		QB_CONDITION.ValueType.STRING_NAME:
			condition.value_string_name = StringName(value)

	return condition


func _make_bool_condition(expected: bool) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.operator = QB_CONDITION.Operator.IS_TRUE if expected else QB_CONDITION.Operator.IS_FALSE
	condition.value_type = QB_CONDITION.ValueType.BOOL
	condition.value_bool = expected
	return condition


func _make_linear_curve(min_val: float = 0.0, max_val: float = 1.0) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, min_val))
	curve.add_point(Vector2(1.0, max_val))
	return curve


func _make_const_curve(output: float) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, output))
	curve.add_point(Vector2(1.0, output))
	return curve


func test_null_curve_passes_returns_1() -> void:
	var condition: Variant = _make_bool_condition(true)
	assert_null(condition.score_curve)
	assert_eq(condition.get_score(true), 1.0)


func test_null_curve_fails_returns_0_via_score_condition() -> void:
	var condition: Variant = QB_CONDITION.new()
	condition.operator = QB_CONDITION.Operator.IS_TRUE
	condition.value_type = QB_CONDITION.ValueType.BOOL
	assert_eq(QB_RULE_EVALUATOR.score_condition(condition, false), 0.0)


func test_score_condition_returns_0_when_condition_fails() -> void:
	var condition: Variant = QB_CONDITION.new()
	condition.operator = QB_CONDITION.Operator.EQUALS
	condition.value_type = QB_CONDITION.ValueType.INT
	condition.value_int = 5
	condition.score_curve = _make_linear_curve()
	assert_eq(QB_RULE_EVALUATOR.score_condition(condition, 99), 0.0)


func test_score_condition_returns_1_when_passes_without_curve() -> void:
	var condition: Variant = QB_CONDITION.new()
	condition.operator = QB_CONDITION.Operator.IS_TRUE
	condition.value_type = QB_CONDITION.ValueType.BOOL
	assert_eq(QB_RULE_EVALUATOR.score_condition(condition, true), 1.0)


func test_linear_curve_proportional_scoring() -> void:
	var curve: Curve = _make_linear_curve()
	var condition: Variant = _make_condition_with_curve(
		QB_CONDITION.Operator.GTE,
		QB_CONDITION.ValueType.FLOAT,
		0.0,
		curve,
		0.0,
		100.0
	)
	condition.value_float = 0.0

	var score: float = condition.get_score(50.0)
	assert_almost_eq(score, 0.5, 0.05)


func test_normalization_range_maps_correctly() -> void:
	var curve: Curve = _make_linear_curve()
	var condition: Variant = QB_CONDITION.new()
	condition.score_curve = curve
	condition.normalize_min = 0.0
	condition.normalize_max = 100.0

	var score: float = condition.get_score(50.0)
	assert_almost_eq(score, 0.5, 0.05)


func test_boolean_values_bypass_normalization() -> void:
	var curve: Curve = _make_linear_curve()
	var condition: Variant = QB_CONDITION.new()
	condition.score_curve = curve
	condition.normalize_min = 50.0
	condition.normalize_max = 200.0

	assert_almost_eq(condition.get_score(true), 1.0, 0.01)
	assert_almost_eq(condition.get_score(false), 0.0, 0.01)


func test_quality_value_below_normalize_min_clamps_to_0() -> void:
	var curve: Curve = _make_linear_curve()
	var condition: Variant = QB_CONDITION.new()
	condition.score_curve = curve
	condition.normalize_min = 10.0
	condition.normalize_max = 100.0

	var score: float = condition.get_score(0.0)
	assert_almost_eq(score, 0.0, 0.01)


func test_quality_value_above_normalize_max_clamps_to_1() -> void:
	var curve: Curve = _make_linear_curve()
	var condition: Variant = QB_CONDITION.new()
	condition.score_curve = curve
	condition.normalize_min = 0.0
	condition.normalize_max = 100.0

	var score: float = condition.get_score(999.0)
	assert_almost_eq(score, 1.0, 0.01)


func test_normalize_min_equals_max_division_by_zero_guard() -> void:
	var curve: Curve = _make_linear_curve()
	var condition: Variant = QB_CONDITION.new()
	condition.score_curve = curve
	condition.normalize_min = 50.0
	condition.normalize_max = 50.0

	assert_almost_eq(condition.get_score(50.0), 1.0, 0.01)
	assert_almost_eq(condition.get_score(49.0), 0.0, 0.01)
	assert_almost_eq(condition.get_score(51.0), 1.0, 0.01)


func test_curve_sample_clamped_to_0_1() -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, -0.5))
	curve.add_point(Vector2(1.0, 1.5))

	var condition: Variant = QB_CONDITION.new()
	condition.score_curve = curve
	condition.normalize_min = 0.0
	condition.normalize_max = 1.0

	assert_true(condition.get_score(0.0) >= 0.0)
	assert_true(condition.get_score(1.0) <= 1.0)


func test_product_aggregation_across_conditions() -> void:
	var linear_curve: Curve = _make_linear_curve()

	var condition_a: Variant = QB_CONDITION.new()
	condition_a.operator = QB_CONDITION.Operator.GTE
	condition_a.value_type = QB_CONDITION.ValueType.FLOAT
	condition_a.value_float = 0.0
	condition_a.score_curve = linear_curve
	condition_a.normalize_min = 0.0
	condition_a.normalize_max = 100.0
	condition_a.quality_path = "value_a"

	var condition_b: Variant = QB_CONDITION.new()
	condition_b.operator = QB_CONDITION.Operator.GTE
	condition_b.value_type = QB_CONDITION.ValueType.FLOAT
	condition_b.value_float = 0.0
	condition_b.score_curve = linear_curve
	condition_b.normalize_min = 0.0
	condition_b.normalize_max = 100.0
	condition_b.quality_path = "value_b"

	var context: Dictionary = {"value_a": 50.0, "value_b": 50.0}
	var score: float = QB_RULE_EVALUATOR.score_all_conditions([condition_a, condition_b], context)

	assert_almost_eq(score, 0.5 * 0.5, 0.05)


func test_zero_score_from_one_condition_zeroes_rule() -> void:
	var linear_curve: Curve = _make_linear_curve()

	var condition_pass: Variant = QB_CONDITION.new()
	condition_pass.operator = QB_CONDITION.Operator.IS_TRUE
	condition_pass.value_type = QB_CONDITION.ValueType.BOOL
	condition_pass.score_curve = linear_curve
	condition_pass.quality_path = "flag"

	var condition_fail: Variant = QB_CONDITION.new()
	condition_fail.operator = QB_CONDITION.Operator.IS_FALSE
	condition_fail.value_type = QB_CONDITION.ValueType.BOOL
	condition_fail.quality_path = "flag"

	var context: Dictionary = {"flag": true}
	assert_eq(QB_RULE_EVALUATOR.score_all_conditions([condition_pass, condition_fail], context), 0.0)


func test_empty_conditions_returns_1() -> void:
	assert_eq(QB_RULE_EVALUATOR.score_all_conditions([], {}), 1.0)
