extends RefCounted
class_name U_QBRuleValidator

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")

static func validate_rule(rule: Variant) -> Array[String]:
	var errors: Array[String] = []
	if rule == null:
		errors.append("rule is null")
		return errors
	if not (rule is Object):
		errors.append("rule must be an Object")
		return errors

	var rule_id: String = _get_string_name_property(rule, "rule_id")
	if rule_id.is_empty():
		errors.append("rule_id must be non-empty")

	var trigger_mode: int = _get_int_property(rule, "trigger_mode", QB_RULE.TriggerMode.TICK)
	var trigger_event: String = _get_string_name_property(rule, "trigger_event")
	if (trigger_mode == QB_RULE.TriggerMode.EVENT or trigger_mode == QB_RULE.TriggerMode.BOTH) and trigger_event.is_empty():
		errors.append("trigger_event is required for EVENT/BOTH trigger modes")

	var conditions: Array = _get_array_property(rule, "conditions")
	for index in range(conditions.size()):
		_validate_condition(conditions[index], index, errors)

	var effects: Array = _get_array_property(rule, "effects")
	for index in range(effects.size()):
		_validate_effect(effects[index], index, errors)

	return errors

static func validate_rule_definitions(definitions: Array) -> Dictionary:
	var valid_rules: Array = []
	var errors_by_index: Dictionary = {}
	var errors_by_rule_id: Dictionary = {}

	for index in range(definitions.size()):
		var rule: Variant = definitions[index]
		var errors: Array[String] = validate_rule(rule)
		if errors.is_empty():
			valid_rules.append(rule)
			continue

		errors_by_index[index] = errors.duplicate()
		var rule_key: StringName = _resolve_rule_report_key(rule, index)
		errors_by_rule_id[rule_key] = errors.duplicate()

	return {
		"valid_rules": valid_rules,
		"errors_by_index": errors_by_index,
		"errors_by_rule_id": errors_by_rule_id,
	}

static func _validate_condition(condition: Variant, index: int, errors: Array[String]) -> void:
	var prefix: String = "conditions[%d]" % index
	if condition == null or not (condition is Object):
		errors.append("%s must be a valid condition resource" % prefix)
		return

	var source: int = _get_int_property(condition, "source", QB_CONDITION.Source.CUSTOM)
	var quality_path: String = _get_string_property(condition, "quality_path", "")
	if quality_path.is_empty() and source != QB_CONDITION.Source.ENTITY_TAG and source != QB_CONDITION.Source.EVENT_PAYLOAD:
		errors.append("%s.quality_path must be non-empty" % prefix)
		return

	if source == QB_CONDITION.Source.COMPONENT and not _is_component_path(quality_path):
		errors.append("%s.quality_path must be Component.field format" % prefix)
	if source == QB_CONDITION.Source.REDUX and not _is_redux_path(quality_path):
		errors.append("%s.quality_path must be slice.field format" % prefix)

static func _validate_effect(effect: Variant, index: int, errors: Array[String]) -> void:
	var prefix: String = "effects[%d]" % index
	if effect == null or not (effect is Object):
		errors.append("%s must be a valid effect resource" % prefix)
		return

	var effect_type: int = _get_int_property(effect, "effect_type", QB_EFFECT.EffectType.SET_QUALITY)
	var target: String = _get_string_property(effect, "target", "")
	if target.is_empty():
		errors.append("%s.target must be non-empty" % prefix)
		return

	if effect_type == QB_EFFECT.EffectType.SET_COMPONENT_FIELD and not _is_component_path(target):
		errors.append("%s.target must be Component.field format for SET_COMPONENT_FIELD" % prefix)

	if effect_type == QB_EFFECT.EffectType.SET_COMPONENT_FIELD or effect_type == QB_EFFECT.EffectType.SET_QUALITY:
		var payload: Dictionary = _get_dict_property(effect, "payload")
		var value_type: Variant = payload.get("value_type", QB_CONDITION.ValueType.BOOL)
		var parsed_value_type: int = QB_EFFECT.try_parse_payload_value_type(value_type)
		if parsed_value_type == QB_EFFECT.INVALID_VALUE_TYPE:
			errors.append("%s.payload.value_type must be FLOAT/INT/STRING/BOOL/STRING_NAME or valid enum value" % prefix)

static func _is_component_path(path: String) -> bool:
	if path.is_empty():
		return false
	var separator_index: int = path.find(".")
	if separator_index <= 0:
		return false
	return separator_index < path.length() - 1

static func _is_redux_path(path: String) -> bool:
	return _is_component_path(path)

static func _get_array_property(object_value: Variant, property_name: String) -> Array:
	if object_value == null or not (object_value is Object):
		return []
	var value: Variant = object_value.get(property_name)
	if value is Array:
		return value as Array
	return []

static func _get_int_property(object_value: Variant, property_name: String, fallback: int) -> int:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	return int(value)

static func _get_string_property(object_value: Variant, property_name: String, fallback: String) -> String:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

static func _get_string_name_property(object_value: Variant, property_name: String) -> String:
	return _get_string_property(object_value, property_name, "")

static func _get_dict_property(object_value: Variant, property_name: String) -> Dictionary:
	if object_value == null or not (object_value is Object):
		return {}
	var value: Variant = object_value.get(property_name)
	if value is Dictionary:
		return value as Dictionary
	return {}

static func _resolve_rule_report_key(rule: Variant, index: int) -> StringName:
	var rule_id: String = _get_string_name_property(rule, "rule_id")
	if not rule_id.is_empty():
		return StringName(rule_id)
	return StringName("rule_%d" % index)
