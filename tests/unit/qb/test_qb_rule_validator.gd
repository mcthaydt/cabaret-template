extends BaseTest

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")
const QB_RULE_VALIDATOR := preload("res://scripts/utils/qb/u_qb_rule_validator.gd")

func _make_condition(source: int, quality_path: String) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.source = source
	condition.quality_path = quality_path
	return condition

func _make_effect(effect_type: int, target: String, payload: Dictionary = {}) -> Variant:
	var effect: Variant = QB_EFFECT.new()
	effect.effect_type = effect_type
	effect.target = target
	effect.payload = payload.duplicate(true)
	return effect

func _make_base_rule() -> Variant:
	var rule: Variant = QB_RULE.new()
	rule.rule_id = StringName("valid_rule")
	rule.trigger_mode = QB_RULE.TriggerMode.TICK
	rule.conditions = [
		_make_condition(QB_CONDITION.Source.REDUX, "gameplay.paused")
	]
	rule.effects = [
		_make_effect(
			QB_EFFECT.EffectType.SET_QUALITY,
			"is_gameplay_active",
			{
				"value_type": QB_CONDITION.ValueType.BOOL,
				"value_bool": false
			}
		)
	]
	return rule

func _errors_contain(errors: Array[String], substring: String) -> bool:
	for message in errors:
		if message.find(substring) != -1:
			return true
	return false

func test_validate_rule_returns_no_errors_for_valid_tick_rule() -> void:
	var rule: Variant = _make_base_rule()
	var errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(rule)
	assert_true(errors.is_empty())

func test_validate_rule_reports_empty_rule_id() -> void:
	var rule: Variant = _make_base_rule()
	rule.rule_id = StringName("")
	var errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(rule)
	assert_false(errors.is_empty())
	assert_true(_errors_contain(errors, "rule_id"))

func test_validate_rule_reports_missing_trigger_event_for_event_and_both_modes() -> void:
	var event_rule: Variant = _make_base_rule()
	event_rule.trigger_mode = QB_RULE.TriggerMode.EVENT
	event_rule.trigger_event = StringName("")
	var event_errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(event_rule)
	assert_true(_errors_contain(event_errors, "trigger_event"))

	var both_rule: Variant = _make_base_rule()
	both_rule.trigger_mode = QB_RULE.TriggerMode.BOTH
	both_rule.trigger_event = StringName("")
	var both_errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(both_rule)
	assert_true(_errors_contain(both_errors, "trigger_event"))

func test_validate_rule_reports_invalid_component_and_redux_paths() -> void:
	var component_rule: Variant = _make_base_rule()
	component_rule.conditions = [
		_make_condition(QB_CONDITION.Source.COMPONENT, "C_HealthComponent")
	]
	var component_errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(component_rule)
	assert_true(_errors_contain(component_errors, "conditions[0].quality_path"))

	var redux_rule: Variant = _make_base_rule()
	redux_rule.conditions = [
		_make_condition(QB_CONDITION.Source.REDUX, "gameplay")
	]
	var redux_errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(redux_rule)
	assert_true(_errors_contain(redux_errors, "conditions[0].quality_path"))

func test_validate_rule_reports_empty_effect_target_and_invalid_component_field_target() -> void:
	var empty_target_rule: Variant = _make_base_rule()
	empty_target_rule.effects = [
		_make_effect(QB_EFFECT.EffectType.PUBLISH_EVENT, "")
	]
	var empty_target_errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(empty_target_rule)
	assert_true(_errors_contain(empty_target_errors, "effects[0].target"))

	var invalid_component_target_rule: Variant = _make_base_rule()
	invalid_component_target_rule.effects = [
		_make_effect(QB_EFFECT.EffectType.SET_COMPONENT_FIELD, "C_HealthComponent")
	]
	var component_target_errors: Array[String] = QB_RULE_VALIDATOR.validate_rule(invalid_component_target_rule)
	assert_true(_errors_contain(component_target_errors, "effects[0].target"))
