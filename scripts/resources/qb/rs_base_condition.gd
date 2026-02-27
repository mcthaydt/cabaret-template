@icon("res://assets/editor_icons/icn_resource.svg")
extends I_Condition
class_name RS_BaseCondition

@export var response_curve: Curve = null
@export var invert: bool = false

func evaluate(context: Dictionary) -> float:
	var raw_score: float = _evaluate_raw(context)
	var score: float = clampf(raw_score, 0.0, 1.0)

	if response_curve != null:
		score = clampf(response_curve.sample_baked(score), 0.0, 1.0)

	if invert:
		score = 1.0 - score

	return clampf(score, 0.0, 1.0)

func _evaluate_raw(_context: Dictionary) -> float:
	return 0.0

func _score_numeric(value: Variant, min_value: float, max_value: float) -> float:
	if not (value is float or value is int):
		return 0.0

	var numeric: float = float(value)
	if is_equal_approx(min_value, max_value):
		return 1.0 if numeric >= min_value else 0.0

	return clampf((numeric - min_value) / (max_value - min_value), 0.0, 1.0)

func _score_numeric_or_bool(value: Variant, min_value: float, max_value: float) -> float:
	if value is bool:
		return 1.0 if bool(value) else 0.0

	return _score_numeric(value, min_value, max_value)

func _matches_string(value: Variant, expected: String) -> bool:
	if value == null:
		return false

	if value is bool:
		var bool_text: String = "true" if bool(value) else "false"
		return bool_text == expected.to_lower()

	if value is StringName:
		return String(value) == expected

	if value is String:
		return value == expected

	return str(value) == expected

func _get_dict_value_string_or_name(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null
