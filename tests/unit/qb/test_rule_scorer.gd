extends BaseTest

const RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const RULE_RESOURCE := preload("res://scripts/core/resources/qb/rs_rule.gd")
const CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")

class ConstantScoreCondition extends I_Condition:
	var score_value: float = 1.0
	var evaluate_calls: int = 0

	func _init(initial_score: float = 1.0) -> void:
		score_value = initial_score

	func evaluate(_context: Dictionary) -> float:
		evaluate_calls += 1
		return score_value

func _make_rule(rule_id: StringName, conditions: Array, threshold: float = 0.0) -> Variant:
	var rule: Variant = RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.conditions.clear()
	for condition_variant in conditions:
		rule.conditions.append(condition_variant)
	rule.score_threshold = threshold
	return rule

func _make_curve(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	for point in points:
		curve.add_point(point, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve

func test_single_condition_rule_score_matches_condition_result() -> void:
	var condition := ConstantScoreCondition.new(0.8)
	var rule: Variant = _make_rule(StringName("single_condition"), [condition])

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_eq(results.size(), 1)
	assert_almost_eq(float(results[0].get("score", -1.0)), 0.8, 0.0001)

func test_multi_condition_rule_multiplies_scores() -> void:
	var condition_a := ConstantScoreCondition.new(0.8)
	var condition_b := ConstantScoreCondition.new(0.5)
	var rule: Variant = _make_rule(StringName("multi_condition"), [condition_a, condition_b])

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_eq(results.size(), 1)
	assert_almost_eq(float(results[0].get("score", -1.0)), 0.4, 0.0001)

func test_short_circuits_on_first_zero_score_condition() -> void:
	var first := ConstantScoreCondition.new(0.0)
	var second := ConstantScoreCondition.new(0.5)
	var rule: Variant = _make_rule(StringName("short_circuit"), [first, second])

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_eq(results.size(), 0)
	assert_eq(first.evaluate_calls, 1)
	assert_eq(second.evaluate_calls, 0)

func test_response_curve_applies_per_condition_before_multiplication() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.5
	condition.response_curve = _make_curve([
		Vector2(0.0, 0.0),
		Vector2(0.5, 0.8),
		Vector2(1.0, 1.0)
	])
	var rule: Variant = _make_rule(StringName("curve_condition"), [condition])

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_eq(results.size(), 1)
	assert_almost_eq(float(results[0].get("score", -1.0)), 0.8, 0.05)

func test_invert_applies_per_condition() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.7
	condition.invert = true
	var rule: Variant = _make_rule(StringName("invert_condition"), [condition])

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_eq(results.size(), 1)
	assert_almost_eq(float(results[0].get("score", -1.0)), 0.3, 0.01)

func test_score_threshold_filters_rules_below_threshold() -> void:
	var condition := ConstantScoreCondition.new(0.4)
	var rule: Variant = _make_rule(StringName("threshold"), [condition], 0.5)

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_true(results.is_empty())

func test_rule_with_empty_conditions_scores_zero() -> void:
	var rule: Variant = _make_rule(StringName("unconditional"), [], 0.0)

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_true(results.is_empty())

func test_empty_rules_array_returns_empty_results() -> void:
	var results: Array = RULE_SCORER.score_rules([], {})
	assert_true(results.is_empty())

func test_results_contain_rule_and_score_dictionary_entries() -> void:
	var condition := ConstantScoreCondition.new(0.9)
	var rule: Variant = _make_rule(StringName("shape"), [condition])

	var results: Array = RULE_SCORER.score_rules([rule], {})
	assert_eq(results.size(), 1)

	var result_entry: Variant = results[0]
	assert_true(result_entry is Dictionary)
	var result_dict: Dictionary = result_entry as Dictionary
	assert_true(result_dict.has("rule"))
	assert_true(result_dict.has("score"))
	assert_eq(result_dict.get("rule"), rule)
	assert_true(result_dict.get("score", null) is float)
