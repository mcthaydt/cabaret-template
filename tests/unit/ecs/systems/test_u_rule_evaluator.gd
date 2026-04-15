extends BaseTest

const RULE_EVALUATOR_PATH := "res://scripts/utils/ecs/u_rule_evaluator.gd"
const RULE_RESOURCE := preload("res://scripts/resources/qb/rs_rule.gd")
const I_CONDITION := preload("res://scripts/interfaces/i_condition.gd")
const I_EFFECT := preload("res://scripts/interfaces/i_effect.gd")
const CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

class ProbeEffect extends I_Effect:
	var execute_calls: int = 0
	var contexts: Array[Dictionary] = []

	func execute(context: Dictionary) -> void:
		execute_calls += 1
		contexts.append(context.duplicate(true))

class ToggleCondition extends I_Condition:
	var score_value: float = 1.0

	func _init(initial_score: float = 1.0) -> void:
		score_value = initial_score

	func evaluate(_context: Dictionary) -> float:
		return score_value

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

func test_refresh_filters_invalid_rules_and_tracks_tick_presence() -> void:
	var evaluator: Variant = _create_evaluator()
	if evaluator == null:
		return

	var default_rule: RS_Rule = _make_rule(StringName("default_tick"), "tick", [_make_constant_condition(1.0)], [])
	var invalid_rule := RULE_RESOURCE.new()
	invalid_rule.rule_id = StringName("invalid_no_conditions")
	var event_rule: RS_Rule = _make_rule(StringName("event_only"), "event", [_make_constant_condition(1.0)], [])
	evaluator.refresh([default_rule, invalid_rule], [event_rule])

	var report: Dictionary = evaluator.get_rule_validation_report()
	var valid_rules_variant: Variant = report.get("valid_rules", [])
	assert_true(valid_rules_variant is Array)
	var valid_rules: Array = valid_rules_variant as Array
	assert_eq(valid_rules.size(), 2)
	assert_true(evaluator.has_tick_rules())

	var errors_by_rule: Dictionary = report.get("errors_by_rule_id", {}) as Dictionary
	assert_true(errors_by_rule.has(StringName("invalid_no_conditions")))

func test_get_applicable_rules_filters_by_trigger_mode_and_custom_rule_filter() -> void:
	var evaluator: Variant = _create_evaluator()
	if evaluator == null:
		return

	var tick_rule: RS_Rule = _make_rule(StringName("tick_rule"), "tick", [_make_constant_condition(1.0)], [])
	var event_rule: RS_Rule = _make_rule(StringName("event_rule"), "event", [_make_constant_condition(1.0)], [])
	var both_rule: RS_Rule = _make_rule(StringName("both_rule"), "both", [_make_constant_condition(1.0)], [])
	evaluator.refresh([], [tick_rule, event_rule, both_rule])

	var tick_rules: Array = evaluator.get_applicable_rules("tick")
	assert_eq(tick_rules.size(), 2)
	assert_true(tick_rules.has(tick_rule))
	assert_true(tick_rules.has(both_rule))

	var event_rules: Array = evaluator.get_applicable_rules(
		"event",
		StringName("sample_event"),
		func(rule_variant: Variant, _event_name: StringName) -> bool:
			return rule_variant == event_rule
	)
	assert_eq(event_rules.size(), 1)
	assert_eq(event_rules[0], event_rule)

func test_subscribe_and_unsubscribe_routes_events_once_per_event_name() -> void:
	var evaluator: Variant = _create_evaluator()
	if evaluator == null:
		return

	var event_rule_a: RS_Rule = _make_rule(StringName("event_a"), "event", [_make_constant_condition(1.0)], [])
	var event_rule_b: RS_Rule = _make_rule(StringName("event_b"), "event", [_make_constant_condition(1.0)], [])
	evaluator.refresh([], [event_rule_a, event_rule_b])

	var callbacks_received: Array[Dictionary] = []
	var extract_event_names := func(_rule_variant: Variant) -> Array[StringName]:
		return [StringName("rule_event")]
	var on_event := func(event_name: StringName, event_payload: Dictionary) -> void:
		callbacks_received.append({
			"name": event_name,
			"payload": event_payload.duplicate(true),
		})
	evaluator.subscribe(extract_event_names, on_event)

	U_ECS_EVENT_BUS.publish(StringName("rule_event"), {"value": 1})
	assert_eq(callbacks_received.size(), 1)

	evaluator.unsubscribe()
	U_ECS_EVENT_BUS.publish(StringName("rule_event"), {"value": 2})
	assert_eq(callbacks_received.size(), 1)

func test_evaluate_applies_cooldown_and_marks_fired_rules() -> void:
	var evaluator: Variant = _create_evaluator()
	if evaluator == null:
		return

	var effect := ProbeEffect.new()
	var cooldown_rule: RS_Rule = _make_rule(
		StringName("cooldown_rule"),
		"tick",
		[_make_constant_condition(1.0)],
		[effect]
	)
	cooldown_rule.cooldown = 1.0
	evaluator.refresh([], [cooldown_rule])

	var context := {}
	evaluator.evaluate(context, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 1)

	evaluator.evaluate(context, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 1)

	evaluator.tick_cooldowns(1.0)
	evaluator.evaluate(context, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 2)

func test_evaluate_enforces_rising_edge_gates_per_context() -> void:
	var evaluator: Variant = _create_evaluator()
	if evaluator == null:
		return

	var condition := ToggleCondition.new(0.0)
	var effect := ProbeEffect.new()
	var rising_rule: RS_Rule = _make_rule(
		StringName("rising_rule"),
		"tick",
		[condition],
		[effect]
	)
	rising_rule.requires_rising_edge = true
	evaluator.refresh([], [rising_rule])

	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 0)

	condition.score_value = 1.0
	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 1)

	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 1)

	condition.score_value = 0.0
	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	condition.score_value = 1.0
	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 2)

func test_resolve_rule_id_falls_back_to_instance_id_for_one_shot_rules() -> void:
	var evaluator: Variant = _create_evaluator()
	if evaluator == null:
		return

	var effect := ProbeEffect.new()
	var one_shot_rule: RS_Rule = _make_rule(StringName(), "tick", [_make_constant_condition(1.0)], [effect])
	one_shot_rule.one_shot = true
	evaluator.refresh([], [one_shot_rule])

	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	evaluator.evaluate({}, "tick", StringName(), StringName("entity_a"))
	assert_eq(effect.execute_calls, 1)

func _create_evaluator() -> Variant:
	var script_obj: Script = load(RULE_EVALUATOR_PATH) as Script
	assert_not_null(script_obj, "U_RuleEvaluator script must exist at %s" % RULE_EVALUATOR_PATH)
	if script_obj == null:
		return null
	return script_obj.new()

func _make_constant_condition(score: float) -> Variant:
	var condition := CONDITION_CONSTANT.new()
	condition.score = score
	return condition

func _make_rule(
	rule_id: StringName,
	trigger_mode: String,
	conditions: Array,
	effects: Array
) -> RS_Rule:
	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = trigger_mode

	rule.conditions.clear()
	for condition_variant in conditions:
		if condition_variant != null and condition_variant is I_CONDITION:
			rule.conditions.append(condition_variant as I_Condition)

	rule.effects.clear()
	for effect_variant in effects:
		if effect_variant != null and effect_variant is I_EFFECT:
			rule.effects.append(effect_variant as I_Effect)

	return rule
