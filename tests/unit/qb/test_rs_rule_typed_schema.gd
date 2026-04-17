extends BaseTest

## Tests for RS_Rule typed-schema enforcement.
##
## These tests verify that RS_Rule.conditions, RS_Rule.effects, and
## RS_ConditionComposite.children use typed arrays (Array[I_Condition],
## Array[I_Effect]) with coerce setters that filter wrong-type entries,
## matching the established pattern in RS_AIGoal and RS_AICompoundTask.

const RS_RULE := preload("res://scripts/resources/qb/rs_rule.gd")
const I_CONDITION := preload("res://scripts/interfaces/i_condition.gd")
const I_EFFECT := preload("res://scripts/interfaces/i_effect.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")
const CONDITION_EVENT_NAME := preload("res://scripts/resources/qb/conditions/rs_condition_event_name.gd")
const CONDITION_COMPOSITE := preload("res://scripts/resources/qb/conditions/rs_condition_composite.gd")
const EFFECT_SET_FIELD := preload("res://scripts/resources/qb/effects/rs_effect_set_field.gd")
const EFFECT_SET_CONTEXT_VALUE := preload("res://scripts/resources/qb/effects/rs_effect_set_context_value.gd")

func _make_redux_condition() -> I_Condition:
	var condition: Variant = CONDITION_REDUX_FIELD.new()
	condition.state_path = "gameplay.is_paused"
	condition.match_mode = "equals"
	condition.match_value_string = "true"
	return condition as I_Condition

func _make_event_condition() -> I_Condition:
	var condition: Variant = CONDITION_EVENT_NAME.new()
	condition.expected_event_name = StringName("entity_death")
	return condition as I_Condition

func _make_set_field_effect() -> I_Effect:
	var effect: Variant = EFFECT_SET_FIELD.new()
	effect.component_type = StringName("C_CameraStateComponent")
	effect.field_name = StringName("shake_trauma")
	return effect as I_Effect

func _make_set_context_value_effect() -> I_Effect:
	var effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	effect.context_key = StringName("is_gameplay_active")
	effect.value_type = "bool"
	effect.bool_value = false
	return effect as I_Effect

# --- Property type annotation tests ---

func test_rule_conditions_has_typed_array_annotation() -> void:
	var rule: Variant = RS_RULE.new()
	var found := false
	for prop in rule.get_property_list():
		if prop.name == "conditions":
			# Godot encodes typed arrays as hint=24 with format "24/17:ClassName"
			# where 24=PROPERTY_HINT_TYPE_STRING, 17=TYPE_OBJECT
			assert_true(prop.hint_string.ends_with("I_Condition"), \
				"conditions property should have I_Condition type hint, got: %s" % prop.hint_string)
			found = true
			break
	assert_true(found, "conditions property should exist in property list")

func test_rule_effects_has_typed_array_annotation() -> void:
	var rule: Variant = RS_RULE.new()
	var found := false
	for prop in rule.get_property_list():
		if prop.name == "effects":
			assert_true(prop.hint_string.ends_with("I_Effect"), \
				"effects property should have I_Effect type hint, got: %s" % prop.hint_string)
			found = true
			break
	assert_true(found, "effects property should exist in property list")

func test_composite_children_has_typed_array_annotation() -> void:
	var composite: Variant = CONDITION_COMPOSITE.new()
	var found := false
	for prop in composite.get_property_list():
		if prop.name == "children":
			assert_true(prop.hint_string.ends_with("I_Condition"), \
				"children property should have I_Condition type hint, got: %s" % prop.hint_string)
			found = true
			break
	assert_true(found, "children property should exist in property list")

# --- Coerce method tests ---
# Test _coerce_conditions/_coerce_effects/_coerce_children directly,
# since GDScript rejects assigning plain Array to Array[I_Condition] properties.

func test_coerce_conditions_filters_wrong_type() -> void:
	var rule: Variant = RS_RULE.new()
	var condition := _make_redux_condition()
	var wrong_type := Resource.new()
	var mixed: Array = [condition, wrong_type]
	var result: Array[I_Condition] = rule._coerce_conditions(mixed)
	assert_eq(result.size(), 1, \
		"coerce should filter out non-I_Condition entries")
	assert_eq(result[0], condition, \
		"only the I_Condition entry should survive")

func test_coerce_conditions_filters_all_wrong_types() -> void:
	var rule: Variant = RS_RULE.new()
	var wrong_type_a := Resource.new()
	var wrong_type_b := Resource.new()
	var all_wrong: Array = [wrong_type_a, wrong_type_b]
	var result: Array[I_Condition] = rule._coerce_conditions(all_wrong)
	assert_eq(result.size(), 0, \
		"coerce should filter all non-I_Condition entries")

func test_coerce_conditions_filters_null() -> void:
	var rule: Variant = RS_RULE.new()
	var condition := _make_redux_condition()
	var mixed: Array = [null, condition, null]
	var result: Array[I_Condition] = rule._coerce_conditions(mixed)
	assert_eq(result.size(), 1, \
		"coerce should filter null entries")
	assert_eq(result[0], condition, \
		"only the valid I_Condition entry should survive")

func test_coerce_conditions_preserves_all_valid() -> void:
	var rule: Variant = RS_RULE.new()
	var cond_a := _make_redux_condition()
	var cond_b := _make_event_condition()
	var valid: Array = [cond_a, cond_b]
	var result: Array[I_Condition] = rule._coerce_conditions(valid)
	assert_eq(result.size(), 2, \
		"coerce should preserve all I_Condition entries")

func test_coerce_effects_filters_wrong_type() -> void:
	var rule: Variant = RS_RULE.new()
	var effect := _make_set_field_effect()
	var wrong_type := Resource.new()
	var mixed: Array = [effect, wrong_type]
	var result: Array[I_Effect] = rule._coerce_effects(mixed)
	assert_eq(result.size(), 1, \
		"coerce should filter out non-I_Effect entries")
	assert_eq(result[0], effect, \
		"only the I_Effect entry should survive")

func test_coerce_effects_preserves_all_valid() -> void:
	var rule: Variant = RS_RULE.new()
	var effect_a := _make_set_field_effect()
	var effect_b := _make_set_context_value_effect()
	var valid: Array = [effect_a, effect_b]
	var result: Array[I_Effect] = rule._coerce_effects(valid)
	assert_eq(result.size(), 2, \
		"coerce should preserve all I_Effect entries")

func test_coerce_children_filters_wrong_type() -> void:
	var composite: Variant = CONDITION_COMPOSITE.new()
	var condition := _make_redux_condition()
	var wrong_type := Resource.new()
	var mixed: Array = [condition, wrong_type]
	var result: Array[I_Condition] = composite._coerce_children(mixed)
	assert_eq(result.size(), 1, \
		"coerce should filter out non-I_Condition entries from children")

func test_coerce_children_filters_null() -> void:
	var composite: Variant = CONDITION_COMPOSITE.new()
	var condition := _make_redux_condition()
	var mixed: Array = [null, condition]
	var result: Array[I_Condition] = composite._coerce_children(mixed)
	assert_eq(result.size(), 1, \
		"coerce should filter null entries from children")

func test_coerce_children_preserves_all_valid() -> void:
	var composite: Variant = CONDITION_COMPOSITE.new()
	var cond_a := _make_redux_condition()
	var cond_b := _make_event_condition()
	var valid: Array = [cond_a, cond_b]
	var result: Array[I_Condition] = composite._coerce_children(valid)
	assert_eq(result.size(), 2, \
		"coerce should preserve all I_Condition entries in children")

# --- Append still works after coerce ---

func test_rule_conditions_append_after_coerce() -> void:
	var rule: Variant = RS_RULE.new()
	var cond_a := _make_redux_condition()
	rule.conditions.clear()
	rule.conditions.append(cond_a)
	var cond_b := _make_event_condition()
	rule.conditions.append(cond_b)
	assert_eq(rule.conditions.size(), 2, \
		"appending valid I_Condition entries should work")

# --- Existing validator still works as semantic double-check ---

func test_rule_validator_catches_semantic_errors_after_typed_schema() -> void:
	var rule: Variant = RS_RULE.new()
	rule.rule_id = StringName("test_rule")
	rule.trigger_mode = "tick"
	var condition := _make_redux_condition()
	rule.conditions.append(condition)
	# No effects — valid for a tick-based rule
	var report: Dictionary = U_RuleValidator.validate_rules([rule])
	var errors: Dictionary = report.get("errors_by_index", {})
	assert_eq(errors.size(), 0, "valid rule should have no errors")