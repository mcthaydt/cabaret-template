extends BaseTest

const RULE_VALIDATOR := preload("res://scripts/utils/qb/u_rule_validator.gd")
const RULE_RESOURCE := preload("res://scripts/resources/qb/rs_rule.gd")
const CONDITION_COMPONENT_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_component_field.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")
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

func test_event_trigger_mode_without_trigger_event_fails() -> void:
	var rule: Variant = _make_valid_rule()
	rule.trigger_mode = "event"
	rule.trigger_event = StringName()
	var report: Dictionary = RULE_VALIDATOR.validate_rules([rule])
	var errors_by_index: Dictionary = _report_errors_by_index(report)
	var rule_errors: Array = errors_by_index.get(0, [])

	assert_true(_errors_contain(rule_errors, "trigger_event"))

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
