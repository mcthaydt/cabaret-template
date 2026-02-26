extends RefCounted
class_name U_RuleValidator

const BASE_CONDITION_SCRIPT := preload("res://scripts/resources/qb/rs_base_condition.gd")
const BASE_EFFECT_SCRIPT := preload("res://scripts/resources/qb/rs_base_effect.gd")
const CONDITION_COMPONENT_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_component_field.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")
const CONDITION_EVENT_PAYLOAD := preload("res://scripts/resources/qb/conditions/rs_condition_event_payload.gd")
const CONDITION_EVENT_NAME := preload("res://scripts/resources/qb/conditions/rs_condition_event_name.gd")
const CONDITION_COMPOSITE := preload("res://scripts/resources/qb/conditions/rs_condition_composite.gd")
const EFFECT_SET_FIELD := preload("res://scripts/resources/qb/effects/rs_effect_set_field.gd")
const MAX_COMPOSITE_VALIDATION_DEPTH: int = 8

static func validate_rules(rules: Array) -> Dictionary:
	var valid_rules: Array = []
	var errors_by_index: Dictionary = {}
	var errors_by_rule_id: Dictionary = {}
	var warnings_by_index: Dictionary = {}
	var warnings_by_rule_id: Dictionary = {}

	for i in range(rules.size()):
		var rule_variant: Variant = rules[i]
		var errors: Array[String] = _validate_rule(rule_variant)
		var warnings: Array[String] = _validate_rule_warnings(rule_variant)
		var rule_id: StringName = _extract_rule_id(rule_variant, i)

		if not errors.is_empty():
			errors_by_index[i] = errors.duplicate()
			errors_by_rule_id[rule_id] = errors.duplicate()
		else:
			if rule_variant != null and rule_variant is Object:
				valid_rules.append(rule_variant)

		if not warnings.is_empty():
			warnings_by_index[i] = warnings.duplicate()
			warnings_by_rule_id[rule_id] = warnings.duplicate()

	return {
		"valid_rules": valid_rules,
		"errors_by_index": errors_by_index,
		"errors_by_rule_id": errors_by_rule_id,
		"warnings_by_index": warnings_by_index,
		"warnings_by_rule_id": warnings_by_rule_id,
	}

static func _validate_rule(rule_variant: Variant) -> Array[String]:
	var errors: Array[String] = []
	if rule_variant == null or not (rule_variant is Object):
		errors.append("rule must be a Resource")
		return errors

	var rule: Object = rule_variant as Object
	var rule_id: StringName = _read_string_name_property(rule, "rule_id")
	if rule_id == StringName():
		errors.append("rule_id must be non-empty")

	var conditions: Array = _read_array_property(rule, "conditions")
	if conditions.is_empty():
		errors.append("conditions must contain at least one entry")

	var trigger_mode: String = _read_string_property(rule, "trigger_mode")
	if (trigger_mode == "event" or trigger_mode == "both") and not _has_event_name_condition(conditions):
		errors.append("event/both trigger modes require an RS_ConditionEventName condition")

	errors.append_array(_validate_conditions(rule))
	errors.append_array(_validate_effects(rule))
	return errors

static func _validate_rule_warnings(rule_variant: Variant) -> Array[String]:
	var warnings: Array[String] = []
	if rule_variant == null or not (rule_variant is Object):
		return warnings

	var rule: Object = rule_variant as Object
	var decision_group: StringName = _read_string_name_property(rule, "decision_group")
	var requires_rising_edge: bool = _read_bool_property(rule, "requires_rising_edge", false)
	var conditions: Array = _read_array_property(rule, "conditions")
	if decision_group != StringName() and conditions.is_empty() and not requires_rising_edge:
		warnings.append("decision_group set on unconditional rule without requires_rising_edge")
	return warnings

static func _validate_conditions(rule: Object) -> Array[String]:
	var errors: Array[String] = []
	var conditions: Array = _read_array_property(rule, "conditions")
	for index in range(conditions.size()):
		var condition_variant: Variant = conditions[index]
		_validate_condition_entry(condition_variant, "conditions[%d]" % index, 0, errors)

	return errors

static func _has_event_name_condition(conditions: Array) -> bool:
	for condition_variant in conditions:
		if _contains_event_name_condition(condition_variant, 0):
			return true
	return false

static func _validate_condition_entry(
	condition_variant: Variant,
	path_prefix: String,
	depth: int,
	errors: Array[String]
) -> void:
	if depth > MAX_COMPOSITE_VALIDATION_DEPTH:
		errors.append("%s nesting depth exceeds %d" % [path_prefix, MAX_COMPOSITE_VALIDATION_DEPTH])
		return
	if condition_variant == null:
		errors.append("%s must be RS_BaseCondition" % path_prefix)
		return
	var condition_object: Object = condition_variant as Object
	if condition_object == null or not _is_script_instance_of(condition_object, BASE_CONDITION_SCRIPT):
		errors.append("%s must be RS_BaseCondition" % path_prefix)
		return

	if _is_script_instance_of(condition_object, CONDITION_COMPOSITE):
		if depth >= MAX_COMPOSITE_VALIDATION_DEPTH:
			errors.append("%s nesting depth exceeds %d" % [path_prefix, MAX_COMPOSITE_VALIDATION_DEPTH])
			return
		var children: Array = _read_array_property(condition_object, "children")
		if children.is_empty():
			errors.append("%s.children must contain at least one entry" % path_prefix)
			return
		_validate_composite_children(children, path_prefix, depth, errors)
		return

	if _is_script_instance_of(condition_object, CONDITION_COMPONENT_FIELD):
		if _read_string_name_property(condition_object, "component_type") == StringName():
			errors.append("%s.component_type must be non-empty" % path_prefix)
		if _read_string_property(condition_object, "field_path").is_empty():
			errors.append("%s.field_path must be non-empty" % path_prefix)
		if _has_invalid_numeric_range(condition_object):
			errors.append("%s.range_min must be less than range_max when both non-zero" % path_prefix)
	elif _is_script_instance_of(condition_object, CONDITION_REDUX_FIELD):
		var state_path: String = _read_string_property(condition_object, "state_path")
		if state_path.is_empty():
			errors.append("%s.state_path must be non-empty" % path_prefix)
		elif state_path.find(".") == -1:
			errors.append("%s.state_path must be in slice.field format" % path_prefix)
		var match_mode: String = _read_string_property(condition_object, "match_mode")
		if match_mode == "normalize" and _has_invalid_numeric_range(condition_object):
			errors.append("%s.range_min must be less than range_max when both non-zero" % path_prefix)
	elif _is_script_instance_of(condition_object, CONDITION_EVENT_PAYLOAD):
		var event_mode: String = _read_string_property(condition_object, "match_mode")
		if event_mode == "normalize" and _has_invalid_numeric_range(condition_object):
			errors.append("%s.range_min must be less than range_max when both non-zero" % path_prefix)
	elif _is_script_instance_of(condition_object, CONDITION_EVENT_NAME):
		if _read_string_name_property(condition_object, "expected_event_name") == StringName():
			errors.append("%s.expected_event_name must be non-empty" % path_prefix)

static func _validate_composite_children(
	children: Array,
	path_prefix: String,
	depth: int,
	errors: Array[String]
) -> void:
	for child_index in range(children.size()):
		var child_variant: Variant = children[child_index]
		_validate_condition_entry(
			child_variant,
			"%s.children[%d]" % [path_prefix, child_index],
			depth + 1,
			errors
		)

static func _contains_event_name_condition(condition_variant: Variant, depth: int) -> bool:
	if depth > MAX_COMPOSITE_VALIDATION_DEPTH:
		return false
	if condition_variant == null or not (condition_variant is Object):
		return false

	var condition_object: Object = condition_variant as Object
	if _is_script_instance_of(condition_object, CONDITION_EVENT_NAME):
		return true
	if not _is_script_instance_of(condition_object, CONDITION_COMPOSITE):
		return false
	if depth >= MAX_COMPOSITE_VALIDATION_DEPTH:
		return false

	var children: Array = _read_array_property(condition_object, "children")
	for child_variant in children:
		if _contains_event_name_condition(child_variant, depth + 1):
			return true
	return false

static func _validate_effects(rule: Object) -> Array[String]:
	var errors: Array[String] = []
	var effects: Array = _read_array_property(rule, "effects")
	for index in range(effects.size()):
		var effect_variant: Variant = effects[index]
		if effect_variant == null:
			errors.append("effects[%d] must be RS_BaseEffect" % index)
			continue
		var effect_object: Object = effect_variant as Object
		if effect_object == null or not _is_script_instance_of(effect_object, BASE_EFFECT_SCRIPT):
			errors.append("effects[%d] must be RS_BaseEffect" % index)
			continue

		if _is_script_instance_of(effect_object, EFFECT_SET_FIELD):
			if _read_string_name_property(effect_object, "component_type") == StringName():
				errors.append("effects[%d].component_type must be non-empty" % index)
			if _read_string_name_property(effect_object, "field_name") == StringName():
				errors.append("effects[%d].field_name must be non-empty" % index)

	return errors

static func _has_invalid_numeric_range(object_value: Object) -> bool:
	var min_value: float = _read_float_property(object_value, "range_min", 0.0)
	var max_value: float = _read_float_property(object_value, "range_max", 0.0)
	if is_zero_approx(min_value) and is_zero_approx(max_value):
		return false
	return min_value >= max_value

static func _is_script_instance_of(object_value: Object, script_ref: Script) -> bool:
	if object_value == null:
		return false
	if script_ref == null:
		return false

	var current: Variant = object_value.get_script()
	while current != null and current is Script:
		if current == script_ref:
			return true
		current = (current as Script).get_base_script()
	return false

static func _extract_rule_id(rule_variant: Variant, index: int) -> StringName:
	if rule_variant != null and rule_variant is Object:
		var rule_id: StringName = _read_string_name_property(rule_variant as Object, "rule_id")
		if rule_id != StringName():
			return rule_id
	return StringName("__index_%d" % index)

static func _read_array_property(object_value: Object, property_name: String) -> Array:
	var value: Variant = object_value.get(property_name)
	if value is Array:
		return value as Array
	return []

static func _read_string_property(object_value: Object, property_name: String) -> String:
	var value: Variant = object_value.get(property_name)
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return ""

static func _read_string_name_property(object_value: Object, property_name: String) -> StringName:
	var value: Variant = object_value.get(property_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName()

static func _read_float_property(object_value: Object, property_name: String, fallback: float) -> float:
	var value: Variant = object_value.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

static func _read_bool_property(object_value: Object, property_name: String, fallback: bool) -> bool:
	var value: Variant = object_value.get(property_name)
	if value is bool:
		return value
	return fallback
