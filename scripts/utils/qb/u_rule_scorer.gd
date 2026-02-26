extends RefCounted
class_name U_RuleScorer

static func score_rules(rules: Array, context: Dictionary) -> Array[Dictionary]:
	if rules.is_empty():
		return []

	var results: Array[Dictionary] = []
	for rule_variant in rules:
		if rule_variant == null or not (rule_variant is Object):
			continue

		var score: float = _score_rule(rule_variant, context)
		var threshold: float = _read_float_property(rule_variant, "score_threshold", 0.0)
		if score <= threshold:
			continue

		results.append({
			"rule": rule_variant,
			"score": score
		})

	return results

static func _score_rule(rule: Variant, context: Dictionary) -> float:
	var conditions: Array = _read_array_property(rule, "conditions")
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
	if not condition.has_method("evaluate"):
		return 0.0

	var raw_score: Variant = condition.call("evaluate", context)
	if not (raw_score is float or raw_score is int):
		return 0.0

	return clampf(float(raw_score), 0.0, 1.0)

static func _read_array_property(object_value: Variant, property_name: String) -> Array:
	if object_value == null or not (object_value is Object):
		return []

	var value: Variant = object_value.get(property_name)
	if value is Array:
		return value as Array

	return []

static func _read_float_property(object_value: Variant, property_name: String, fallback: float) -> float:
	if object_value == null or not (object_value is Object):
		return fallback

	var value: Variant = object_value.get(property_name)
	if value is float or value is int:
		return float(value)

	return fallback
