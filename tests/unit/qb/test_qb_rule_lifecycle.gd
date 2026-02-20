extends BaseTest

const BASE_QB_RULE_MANAGER := preload("res://scripts/ecs/systems/base_qb_rule_manager.gd")
const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

class RuleManagerStub:
	extends "res://scripts/ecs/systems/base_qb_rule_manager.gd"

	var contexts: Array = []
	var default_rules: Array = []

	func _get_tick_contexts(_delta: float) -> Array:
		return contexts

	func get_default_rule_definitions() -> Array:
		return default_rules

class CharacterStateStub:
	extends RefCounted

	var is_dead: bool = false

func before_each() -> void:
	U_ECSEventBus.reset()

func _configure_manager(
	rules: Array = [],
	default_rules: Array = []
) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var manager := RuleManagerStub.new()
	manager.rule_definitions = rules
	manager.default_rules = default_rules
	manager.state_store = store
	manager.ecs_manager = ecs_manager
	autofree(manager)
	manager.configure(ecs_manager)

	return {
		"manager": manager,
		"store": store,
		"ecs_manager": ecs_manager,
	}

func _make_condition(
	path: String,
	source: int = QB_CONDITION.Source.CUSTOM,
	operator: int = QB_CONDITION.Operator.IS_TRUE
) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.source = source
	condition.quality_path = path
	condition.operator = operator
	condition.value_type = QB_CONDITION.ValueType.BOOL
	condition.value_bool = true
	return condition

func _make_dispatch_effect(action_type: StringName, payload: Dictionary) -> Variant:
	var effect: Variant = QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.DISPATCH_ACTION
	effect.target = String(action_type)
	effect.payload = payload.duplicate(true)
	return effect

func _make_set_quality_effect(target: String, value: bool) -> Variant:
	var effect: Variant = QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.SET_QUALITY
	effect.target = target
	effect.payload = {
		"value_type": QB_CONDITION.ValueType.BOOL,
		"value_bool": value,
	}
	return effect

func _make_rule(
	rule_id: StringName,
	conditions: Array,
	effects: Array,
	priority: int = 0,
	requires_salience: bool = true,
	cooldown: float = 0.0,
	trigger_mode: int = QB_RULE.TriggerMode.TICK,
	trigger_event: StringName = StringName(),
	is_one_shot: bool = false,
	cooldown_key_fields: Array[String] = [],
	cooldown_from_context_field: String = ""
) -> Variant:
	var rule: Variant = QB_RULE.new()
	rule.rule_id = rule_id
	rule.conditions = conditions
	rule.effects = effects
	rule.priority = priority
	rule.requires_salience = requires_salience
	rule.cooldown = cooldown
	rule.trigger_mode = trigger_mode
	rule.trigger_event = trigger_event
	rule.is_one_shot = is_one_shot
	rule.cooldown_key_fields = cooldown_key_fields
	rule.cooldown_from_context_field = cooldown_from_context_field
	return rule

func test_salience_only_fires_on_false_to_true_transition() -> void:
	var rule: Variant = _make_rule(
		StringName("salience_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/salience"), {})],
		0,
		true
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": false}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 0)

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.contexts = [{"flag": false}]
	manager.process_tick(0.016)
	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 2)

func test_cooldown_blocks_retrigger_until_elapsed() -> void:
	var rule: Variant = _make_rule(
		StringName("cooldown_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/cooldown"), {})],
		0,
		false,
		1.0
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.process_tick(0.25)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.process_tick(0.80)
	assert_eq(store.get_dispatched_actions().size(), 2)

func test_one_shot_rule_only_executes_once() -> void:
	var rule: Variant = _make_rule(
		StringName("one_shot_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/one_shot"), {})],
		0,
		false,
		0.0,
		QB_RULE.TriggerMode.TICK,
		StringName(),
		true
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 1)

func test_higher_priority_rules_execute_first() -> void:
	var high_rule: Variant = _make_rule(
		StringName("rule_a"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/high"), {"order": "A"})],
		10,
		false
	)
	var low_rule: Variant = _make_rule(
		StringName("rule_b"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/low"), {"order": "B"})],
		5,
		false
	)
	var context := _configure_manager([low_rule, high_rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 2)
	if actions.size() < 2:
		return
	assert_eq(actions[0].get("payload", {}).get("order"), "A")
	assert_eq(actions[1].get("payload", {}).get("order"), "B")

func test_event_mode_salience_is_auto_disabled() -> void:
	var rule: Variant = _make_rule(
		StringName("event_rule"),
		[
			_make_condition("triggered", QB_CONDITION.Source.EVENT_PAYLOAD, QB_CONDITION.Operator.IS_TRUE)
		],
		[_make_dispatch_effect(StringName("qb/event"), {})],
		0,
		true,
		0.0,
		QB_RULE.TriggerMode.EVENT,
		StringName("qb_test_event")
	)
	var context := _configure_manager([rule])
	var store: MockStateStore = context["store"]

	U_ECSEventBus.publish(StringName("qb_test_event"), {"triggered": true})
	U_ECSEventBus.publish(StringName("qb_test_event"), {"triggered": true})

	assert_eq(store.get_dispatched_actions().size(), 2)

func test_per_context_cooldowns_are_independent() -> void:
	var rule: Variant = _make_rule(
		StringName("context_cooldown_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/context"), {})],
		0,
		false,
		1.0,
		QB_RULE.TriggerMode.TICK,
		StringName(),
		false,
		["entity_id"]
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": true, "entity_id": "A"}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.contexts = [
		{"flag": true, "entity_id": "A"},
		{"flag": true, "entity_id": "B"},
	]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 2)

	manager.contexts = [{"flag": true, "entity_id": "A"}]
	manager.process_tick(0.25)
	assert_eq(store.get_dispatched_actions().size(), 2)

	manager.process_tick(1.0)
	assert_eq(store.get_dispatched_actions().size(), 3)

func test_cooldown_from_context_field_overrides_rule_cooldown() -> void:
	var rule: Variant = _make_rule(
		StringName("context_cooldown_override_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/cooldown_override"), {})],
		0,
		false,
		5.0,
		QB_RULE.TriggerMode.TICK,
		StringName(),
		false,
		[],
		"cooldown_override"
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": true, "cooldown_override": 0.3}]
	manager.process_tick(0.016)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.process_tick(0.2)
	assert_eq(store.get_dispatched_actions().size(), 1)

	manager.process_tick(0.2)
	assert_eq(store.get_dispatched_actions().size(), 2)

func test_stale_context_state_is_cleaned_up() -> void:
	var rule: Variant = _make_rule(
		StringName("stale_cleanup_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/stale_cleanup"), {})],
		0,
		false,
		2.0,
		QB_RULE.TriggerMode.TICK,
		StringName(),
		false,
		["entity_id"]
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]

	manager.contexts = [
		{"flag": true, "entity_id": "A"},
		{"flag": true, "entity_id": "B"},
	]
	manager.process_tick(0.016)

	manager.contexts = [
		{"flag": true, "entity_id": "A"},
	]
	manager.process_tick(0.016)

	var state: Dictionary = manager.get_rule_runtime_state(StringName("stale_cleanup_rule"))
	var context_cooldowns: Dictionary = state.get("context_cooldowns", {})
	assert_true(context_cooldowns.has("A"))
	assert_false(context_cooldowns.has("B"))

func test_set_quality_only_mutates_context_dictionary() -> void:
	var rule: Variant = _make_rule(
		StringName("set_quality_rule"),
		[_make_condition("flag")],
		[_make_set_quality_effect("is_dead", true)],
		0,
		false
	)
	var context := _configure_manager([rule])
	var manager: RuleManagerStub = context["manager"]

	var component := CharacterStateStub.new()
	component.is_dead = false
	var tick_context: Dictionary = {
		"flag": true,
		"is_dead": false,
		"components": {
			"C_CharacterStateComponent": component
		}
	}
	manager.contexts = [tick_context]
	manager.process_tick(0.016)

	assert_eq(tick_context.get("is_dead"), true)
	assert_eq(component.is_dead, false)

func test_on_configured_filters_invalid_rules_via_validator() -> void:
	var valid_rule: Variant = _make_rule(
		StringName("valid_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/valid"), {})],
		0,
		false
	)

	var invalid_effect: Variant = QB_EFFECT.new()
	invalid_effect.effect_type = QB_EFFECT.EffectType.SET_QUALITY
	invalid_effect.target = "is_dead"
	invalid_effect.payload = {
		"value_type": "NOT_A_REAL_VALUE_TYPE",
		"value_bool": true,
	}
	var invalid_rule: Variant = _make_rule(
		StringName("invalid_rule"),
		[_make_condition("flag")],
		[invalid_effect],
		0,
		false
	)

	var context := _configure_manager([valid_rule, invalid_rule])
	var manager: RuleManagerStub = context["manager"]

	var registered_rule_ids: Array[StringName] = manager.get_registered_rule_ids()
	assert_eq(registered_rule_ids, [StringName("valid_rule")])

	var validation_report: Dictionary = manager.get_rule_validation_report()
	var errors_by_rule_id: Dictionary = validation_report.get("errors_by_rule_id", {})
	assert_true(errors_by_rule_id.has(StringName("invalid_rule")))

func test_default_rule_definitions_used_when_export_array_empty() -> void:
	var default_rule: Variant = _make_rule(
		StringName("default_rule"),
		[_make_condition("flag")],
		[_make_dispatch_effect(StringName("qb/default"), {})],
		0,
		false
	)
	var context := _configure_manager([], [default_rule])
	var manager: RuleManagerStub = context["manager"]
	var store: MockStateStore = context["store"]

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.016)

	assert_eq(store.get_dispatched_actions().size(), 1)
