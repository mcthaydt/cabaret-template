extends BaseTest

const RULE_VALIDATOR := preload("res://scripts/utils/qb/u_rule_validator.gd")
const RULE_RESOURCE := preload("res://scripts/resources/qb/rs_rule.gd")
const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")
const CONDITION_COMPONENT_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_component_field.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")
const CONDITION_EVENT_NAME := preload("res://scripts/resources/qb/conditions/rs_condition_event_name.gd")
const CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")
const CONDITION_COMPOSITE := preload("res://scripts/resources/qb/conditions/rs_condition_composite.gd")
const EFFECT_SET_FIELD := preload("res://scripts/resources/qb/effects/rs_effect_set_field.gd")
const EFFECT_SET_CONTEXT_VALUE := preload("res://scripts/resources/qb/effects/rs_effect_set_context_value.gd")

func _make_valid_rule() -> Variant:
	var rule: Variant = RULE_RESOURCE.new()
	rule.rule_id = StringName("valid_rule")
	rule.trigger_mode = "tick"
	rule.conditions.clear()
	rule.effects.clear()

	var condition: Variant = CONDITION_REDUX_FIELD.new()
	condition.state_path = "gameplay.is_paused"
	condition.match_mode = "equals"
	condition.match_value_string = "true"
	rule.conditions.append(condition)

	var effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	effect.context_key = StringName("is_gameplay_active")
	effect.value_type = "bool"
	effect.bool_value = false
	rule.effects.append(effect)
	return rule

func _report_errors_by_index(report: Dictionary) -> Dictionary:
	var value: Variant = report.get("errors_by_index", {})
	return value as Dictionary if value is Dictionary else {}

func _report_warnings_by_index(report: Dictionary) -> Dictionary:
	var value: Variant = report.get("warnings_by_index", {})
	return value as Dictionary if value is Dictionary else {}

func _errors_contain(errors: Array, substring: String) -> bool:
	for message_variant in errors:
		var message: String = str(message_variant)
		if message.find(substring) != -1:
			return true
	return false

func _make_composite_chain(levels: int, leaf_condition: Resource) -> Resource:
	var current: Resource = leaf_condition
	for _i in range(levels):
		var composite: Variant = CONDITION_COMPOSITE.new()
		composite.mode = CONDITION_COMPOSITE.CompositeMode.ALL
		composite.children.clear()
		composite.children.append(current as I_Condition)
		current = composite
	return current

func test_valid_rule_with_conditions_and_effects_passes() -> void:
	var report: Dictionary = RULE_VALIDATOR.validate_rules([_make_valid_rule()])
	var valid_rules: Array = report.get("valid_rules", [])
	var errors_by_index: Dictionary = _report_errors_by_index(report)

	assert_eq(valid_rules.size(), 1)
	assert_true(errors_by_index.is_empty())

func test_empty_rule_id_fails_validation() -> void:
	var rule: Variant = _make_valid_rule()
	rule.rule_id = StringName()
	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])

	assert_true(_errors_contain(rule_errors, "rule_id"))

func test_rule_without_conditions_fails_validation() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])

	assert_true(_errors_contain(rule_errors, "conditions"))

func test_event_trigger_mode_without_event_name_condition_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.trigger_mode = "event"
	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])

	assert_true(_errors_contain(rule_errors, "RS_ConditionEventName"))

func test_component_field_condition_with_empty_component_type_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var condition: Variant = CONDITION_COMPONENT_FIELD.new()
	condition.component_type = StringName()
	condition.field_path = "health_percent"
	rule.conditions.append(condition)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "component_type"))

func test_redux_field_condition_with_empty_state_path_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var condition: Variant = CONDITION_REDUX_FIELD.new()
	condition.state_path = ""
	rule.conditions.append(condition)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "state_path"))

func test_redux_field_condition_without_dot_separator_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var condition: Variant = CONDITION_REDUX_FIELD.new()
	condition.state_path = "gameplay"
	rule.conditions.append(condition)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "state_path"))

func test_effect_set_field_with_empty_component_type_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.effects.clear()
	var effect: Variant = EFFECT_SET_FIELD.new()
	effect.component_type = StringName()
	effect.field_name = StringName("target_fov")
	rule.effects.append(effect)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "component_type"))

func test_effect_set_field_with_empty_field_name_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.effects.clear()
	var effect: Variant = EFFECT_SET_FIELD.new()
	effect.component_type = StringName("C_CameraStateComponent")
	effect.field_name = StringName()
	rule.effects.append(effect)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "field_name"))

func test_range_min_greater_or_equal_range_max_fails_when_both_non_zero() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var condition: Variant = CONDITION_COMPONENT_FIELD.new()
	condition.component_type = StringName("C_HealthComponent")
	condition.field_path = "health_percent"
	condition.range_min = 10.0
	condition.range_max = 10.0
	rule.conditions.append(condition)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "range_min"))

func test_event_name_condition_with_empty_expected_event_name_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()

	var condition: Variant = CONDITION_EVENT_NAME.new()
	condition.expected_event_name = StringName()
	rule.conditions.append(condition)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "expected_event_name"))

func test_grouped_unconditional_rule_without_rising_edge_emits_warning() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	rule.decision_group = StringName("pause_gate")
	rule.requires_rising_edge = false

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var warnings_by_index: Dictionary = _report_warnings_by_index(report)
	var warnings: Array = warnings_by_index.get(0, [])
	assert_true(_errors_contain(warnings, "decision_group"))

func test_validate_rules_returns_expected_report_structure() -> void:
	var report: Dictionary = RULE_VALIDATOR.validate_rules([_make_valid_rule()])

	assert_true(report.has("valid_rules"))
	assert_true(report.has("errors_by_index"))
	assert_true(report.has("errors_by_rule_id"))

	assert_true(report.get("valid_rules", null) is Array)
	assert_true(report.get("errors_by_index", null) is Dictionary)
	assert_true(report.get("errors_by_rule_id", null) is Dictionary)

func test_composite_condition_with_empty_children_fails_validation() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var condition: Variant = CONDITION_COMPOSITE.new()
	condition.mode = CONDITION_COMPOSITE.CompositeMode.ALL
	var empty_children: Array[I_Condition] = []
	condition.children = empty_children
	rule.conditions.append(condition)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "children"))

func test_composite_condition_with_valid_children_passes_validation() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()
	var composite: Variant = CONDITION_COMPOSITE.new()
	composite.mode = CONDITION_COMPOSITE.CompositeMode.ANY
	var child: Variant = CONDITION_REDUX_FIELD.new()
	child.state_path = "gameplay.is_paused"
	child.match_mode = "equals"
	child.match_value_string = "true"
	var children: Array[I_Condition] = [child as I_Condition]
	composite.children = children
	rule.conditions.append(composite)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	assert_true(errors_by_index.is_empty())

func test_nested_composite_condition_recurses_for_validation_errors() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()

	var nested_bad: Variant = CONDITION_REDUX_FIELD.new()
	nested_bad.state_path = ""
	var inner: Variant = CONDITION_COMPOSITE.new()
	inner.mode = CONDITION_COMPOSITE.CompositeMode.ALL
	var inner_children: Array[I_Condition] = [nested_bad as I_Condition]
	inner.children = inner_children

	var outer: Variant = CONDITION_COMPOSITE.new()
	outer.mode = CONDITION_COMPOSITE.CompositeMode.ANY
	var outer_children: Array[I_Condition] = [inner as I_Condition]
	outer.children = outer_children

	rule.conditions.append(outer)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "state_path"))

func test_event_name_nested_inside_composite_satisfies_event_mode_requirement() -> void:
	var rule: Variant = _make_valid_rule()
	rule.trigger_mode = "event"
	rule.conditions.clear()

	var event_name: Variant = CONDITION_EVENT_NAME.new()
	event_name.expected_event_name = StringName("victory_triggered")
	var literal: Variant = CONDITION_CONSTANT.new()
	literal.score = 1.0

	var composite: Variant = CONDITION_COMPOSITE.new()
	composite.mode = CONDITION_COMPOSITE.CompositeMode.ANY
	var children: Array[I_Condition] = [literal as I_Condition, event_name as I_Condition]
	composite.children = children
	rule.conditions.append(composite)

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	assert_true(errors_by_index.is_empty())

func test_composite_depth_limit_allows_boundary_depth() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()

	var leaf: Variant = CONDITION_REDUX_FIELD.new()
	leaf.state_path = "gameplay.is_paused"
	leaf.match_mode = "equals"
	leaf.match_value_string = "true"

	rule.conditions.append(_make_composite_chain(8, leaf))

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	assert_true(errors_by_index.is_empty())

func test_composite_depth_limit_rejects_exceeding_depth() -> void:
	var rule: Variant = _make_valid_rule()
	rule.conditions.clear()

	var leaf: Variant = CONDITION_REDUX_FIELD.new()
	leaf.state_path = "gameplay.is_paused"
	leaf.match_mode = "equals"
	leaf.match_value_string = "true"

	rule.conditions.append(_make_composite_chain(9, leaf))

	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])
	assert_true(_errors_contain(rule_errors, "nesting depth exceeds"))
