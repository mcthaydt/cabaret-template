extends RefCounted
class_name U_RuleScorer

const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")

static func score_rules(rules: Array, context: Dictionary) -> Array[Dictionary]:
	if rules.is_empty():
		return []

	var results: Array[Dictionary] = []
	for rule_variant in rules:
		if rule_variant == null or not (rule_variant is Object):
			continue

		var score: float = _score_rule(rule_variant, context)
		var threshold: float = U_RULE_UTILS.read_float_property(rule_variant, "score_threshold", 0.0)
		if score <= threshold:
			continue

		results.append({
			"rule": rule_variant,
			"score": score
		})

	return results

static func _score_rule(rule: Variant, context: Dictionary) -> float:
	var conditions: Array = U_RULE_UTILS.read_array_property(rule, "conditions")
	if conditions.is_empty():
		return 0.0

	var score: float = 1.0
	for condition_variant in conditions:
		var condition_score: float = _evaluate_condition(condition_variant, context)
		score *= condition_score
		if score <= 0.0:
			return 0.0

	return clampf(score, 0.0, 1.0)

static func _evaluate_condition(condition: Variant, context: Dictionary) -> float:
	if condition == null or not (condition is Object):
		return 0.0
	if not condition is I_Condition:
		return 0.0

	var raw_score: Variant = condition.call("evaluate", context)
	if not (raw_score is float or raw_score is int):
		return 0.0

	return clampf(float(raw_score), 0.0, 1.0)