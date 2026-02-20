extends RefCounted
class_name U_QBRuleEvaluator

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const U_QB_VARIANT_UTILS := preload("res://scripts/utils/qb/u_qb_variant_utils.gd")

static func evaluate_condition(condition: Variant, quality_value: Variant) -> bool:
	if condition == null:
		return false
	if not (condition is Object):
		return false

	var value_type: int = U_QB_VARIANT_UTILS.get_int_property(condition, "value_type", QB_CONDITION.ValueType.BOOL)
	var operator: int = U_QB_VARIANT_UTILS.get_int_property(condition, "operator", QB_CONDITION.Operator.EQUALS)
	var negate: bool = U_QB_VARIANT_UTILS.get_bool_property(condition, "negate", false)
	var expected_value: Variant = _get_expected_value(condition)
	var result: bool = false

	match operator:
		QB_CONDITION.Operator.EQUALS:
			result = _evaluate_equals(value_type, quality_value, expected_value)
		QB_CONDITION.Operator.NOT_EQUALS:
			result = not _evaluate_equals(value_type, quality_value, expected_value)
		QB_CONDITION.Operator.GREATER_THAN:
			result = _evaluate_numeric_comparison(value_type, quality_value, expected_value, QB_CONDITION.Operator.GREATER_THAN)
		QB_CONDITION.Operator.LESS_THAN:
			result = _evaluate_numeric_comparison(value_type, quality_value, expected_value, QB_CONDITION.Operator.LESS_THAN)
		QB_CONDITION.Operator.GTE:
			result = _evaluate_numeric_comparison(value_type, quality_value, expected_value, QB_CONDITION.Operator.GTE)
		QB_CONDITION.Operator.LTE:
			result = _evaluate_numeric_comparison(value_type, quality_value, expected_value, QB_CONDITION.Operator.LTE)
		QB_CONDITION.Operator.HAS:
			result = _evaluate_has(value_type, quality_value, expected_value)
		QB_CONDITION.Operator.NOT_HAS:
			result = not _evaluate_has(value_type, quality_value, expected_value)
		QB_CONDITION.Operator.IS_TRUE:
			result = quality_value is bool and bool(quality_value)
		QB_CONDITION.Operator.IS_FALSE:
			result = quality_value is bool and not bool(quality_value)
		_:
			result = false

	if negate:
		return not result
	return result

## Test-only convenience helper.
## Production rule execution should flow through BaseQBRuleManager lifecycle APIs.
static func evaluate_all_conditions(conditions: Array, context: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	for condition_variant in conditions:
		var condition: Variant = condition_variant
		if condition == null:
			return false

		var quality_path: String = U_QB_VARIANT_UTILS.get_string_property(condition, "quality_path", "")
		var quality_value: Variant = _resolve_quality_value(context, quality_path)
		if not evaluate_condition(condition, quality_value):
			return false

	return true

static func _evaluate_equals(value_type: int, quality_value: Variant, expected_value: Variant) -> bool:
	var normalized_quality: Variant = _normalize_value_for_type(value_type, quality_value)
	if normalized_quality == null:
		return false
	var normalized_expected: Variant = _normalize_value_for_type(value_type, expected_value)
	if normalized_expected == null:
		return false
	return normalized_quality == normalized_expected

static func _evaluate_numeric_comparison(value_type: int, quality_value: Variant, expected_value: Variant, operator: int) -> bool:
	var quality_number: Variant = _normalize_numeric(value_type, quality_value)
	var expected_number: Variant = _normalize_numeric(value_type, expected_value)
	if quality_number == null or expected_number == null:
		return false

	var actual: float = float(quality_number)
	var expected: float = float(expected_number)

	match operator:
		QB_CONDITION.Operator.GREATER_THAN:
			return actual > expected
		QB_CONDITION.Operator.LESS_THAN:
			return actual < expected
		QB_CONDITION.Operator.GTE:
			return actual >= expected
		QB_CONDITION.Operator.LTE:
			return actual <= expected
		_:
			return false

static func _evaluate_has(value_type: int, quality_value: Variant, expected_value: Variant) -> bool:
	if quality_value is Array:
		var quality_array: Array = quality_value
		for entry in quality_array:
			if _evaluate_equals(value_type, entry, expected_value):
				return true
		return false

	if quality_value is Dictionary:
		var quality_dict: Dictionary = quality_value
		var key_variant: Variant = _normalize_value_for_type(value_type, expected_value)
		if key_variant == null:
			return false

		if quality_dict.has(key_variant):
			return true
		if key_variant is StringName:
			var as_string: String = String(key_variant)
			return quality_dict.has(as_string)
		if key_variant is String:
			var as_name: StringName = StringName(key_variant)
			return quality_dict.has(as_name)
		return false

	if quality_value is String or quality_value is StringName:
		var text: String = String(quality_value)
		var expected_text_variant: Variant = _normalize_value_for_type(value_type, expected_value)
		if expected_text_variant == null:
			return false
		var expected_text: String = String(expected_text_variant)
		return text.find(expected_text) != -1

	return false

static func _normalize_numeric(value_type: int, value: Variant) -> Variant:
	if value == null:
		return null
	if value_type != QB_CONDITION.ValueType.FLOAT and value_type != QB_CONDITION.ValueType.INT:
		return null
	if value is float or value is int:
		return float(value)
	return null

static func _normalize_value_for_type(value_type: int, value: Variant) -> Variant:
	if value == null:
		return null

	match value_type:
		QB_CONDITION.ValueType.FLOAT:
			if value is float or value is int:
				return float(value)
			return null
		QB_CONDITION.ValueType.INT:
			if value is int:
				return value
			if value is float:
				return int(value)
			return null
		QB_CONDITION.ValueType.STRING:
			if value is String or value is StringName:
				return String(value)
			return null
		QB_CONDITION.ValueType.BOOL:
			if value is bool:
				return bool(value)
			return null
		QB_CONDITION.ValueType.STRING_NAME:
			if value is StringName:
				return value
			if value is String:
				return StringName(value)
			return null
		_:
			return null

static func _resolve_quality_value(context: Dictionary, quality_path: String) -> Variant:
	if quality_path.is_empty():
		return null

	if context.has(quality_path):
		return context.get(quality_path)

	var segments: PackedStringArray = quality_path.split(".")
	if segments.is_empty():
		return null

	var current: Variant = context
	for segment in segments:
		if not (current is Dictionary):
			return null
		var current_dict: Dictionary = current
		if current_dict.has(segment):
			current = current_dict.get(segment)
			continue

		var segment_name: StringName = StringName(segment)
		if current_dict.has(segment_name):
			current = current_dict.get(segment_name)
			continue

		return null

	return current

static func _get_expected_value(condition: Variant) -> Variant:
	if condition == null:
		return null
	if condition is Object and condition.has_method("get_typed_value"):
		return condition.call("get_typed_value")
	return null
