extends BaseTest

const GAME_EVENT_SYSTEM := preload("res://scripts/core/ecs/systems/s_game_event_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

const RULE_RESOURCE := preload("res://scripts/core/resources/qb/rs_rule.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd")
const CONDITION_EVENT_NAME := preload("res://scripts/core/resources/qb/conditions/rs_condition_event_name.gd")
const CONDITION_COMPOSITE := preload("res://scripts/core/resources/qb/conditions/rs_condition_composite.gd")
const CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")
const EFFECT_DISPATCH_ACTION := preload("res://scripts/core/resources/qb/effects/rs_effect_dispatch_action.gd")
const EFFECT_PUBLISH_EVENT := preload("res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd")

const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")
const I_EFFECT := preload("res://scripts/core/interfaces/i_effect.gd")

const C_CHECKPOINT_COMPONENT := preload("res://scripts/core/ecs/components/c_checkpoint_component.gd")
const C_VICTORY_TRIGGER_COMPONENT := preload("res://scripts/core/ecs/components/c_victory_trigger_component.gd")

const EVENT_CUSTOM_RULE_TRIGGER := StringName("custom_rule_trigger")
const EVENT_CUSTOM_FORWARD_SOURCE := StringName("custom_forward_source")
const EVENT_CUSTOM_FORWARD_TARGET := StringName("custom_forward_target")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_checkpoint_event_received_publishes_checkpoint_activation_requested_with_full_payload() -> void:
	var fixture: Dictionary = await _create_fixture()
	var checkpoint := C_CHECKPOINT_COMPONENT.new()
	autofree(checkpoint)
	var body := CharacterBody3D.new()
	autofree(body)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_CHECKPOINT_ZONE_ENTERED, {
		"entity_id": StringName("player"),
		"checkpoint": checkpoint,
		"spawn_point_id": StringName("sp_checkpoint"),
		"body": body,
	})
	await _pump()

	var events: Array = _find_events_by_name(
		U_ECSEventBus.get_event_history(),
		U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED
	)
	assert_eq(events.size(), 1)
	if events.is_empty():
		return

	var payload_variant: Variant = events[0].get("payload", {})
	assert_true(payload_variant is Dictionary)
	var payload: Dictionary = payload_variant as Dictionary
	assert_eq(payload.get("entity_id", StringName()), StringName("player"))
	assert_eq(payload.get("checkpoint", null), checkpoint)
	assert_eq(payload.get("spawn_point_id", StringName()), StringName("sp_checkpoint"))
	assert_eq(payload.get("body", null), body)
	assert_eq((fixture["store"] as MockStateStore).get_dispatched_actions().size(), 0)

func test_victory_event_received_publishes_victory_execution_requested_with_full_payload() -> void:
	var fixture: Dictionary = await _create_fixture()
	var trigger := C_VICTORY_TRIGGER_COMPONENT.new()
	autofree(trigger)
	var body := CharacterBody3D.new()
	autofree(body)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_TRIGGERED, {
		"entity_id": StringName("player"),
		"trigger_node": trigger,
		"body": body,
	})
	await _pump()

	var events: Array = _find_events_by_name(
		U_ECSEventBus.get_event_history(),
		U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED
	)
	assert_eq(events.size(), 1)
	if events.is_empty():
		return

	var payload_variant: Variant = events[0].get("payload", {})
	assert_true(payload_variant is Dictionary)
	var payload: Dictionary = payload_variant as Dictionary
	assert_eq(payload.get("entity_id", StringName()), StringName("player"))
	assert_eq(payload.get("trigger_node", null), trigger)
	assert_eq(payload.get("body", null), body)
	assert_eq((fixture["store"] as MockStateStore).get_dispatched_actions().size(), 0)

func test_entity_id_from_event_context_is_injected_into_published_payload() -> void:
	var custom_rule: RS_Rule = _make_event_publish_rule(
		StringName("inject_entity_id_rule"),
		EVENT_CUSTOM_FORWARD_SOURCE,
		EVENT_CUSTOM_FORWARD_TARGET,
		{"reason": "test"}
	)
	var fixture: Dictionary = await _create_fixture([custom_rule])

	U_ECSEventBus.publish(EVENT_CUSTOM_FORWARD_SOURCE, {
		"entity_id": StringName("player_custom"),
	})
	await _pump()

	var events: Array = _find_events_by_name(U_ECSEventBus.get_event_history(), EVENT_CUSTOM_FORWARD_TARGET)
	assert_eq(events.size(), 1)
	if events.is_empty():
		return

	var payload_variant: Variant = events[0].get("payload", {})
	assert_true(payload_variant is Dictionary)
	var payload: Dictionary = payload_variant as Dictionary
	assert_eq(payload.get("reason", ""), "test")
	assert_eq(payload.get("entity_id", StringName()), StringName("player_custom"))
	assert_eq((fixture["store"] as MockStateStore).get_dispatched_actions().size(), 0)

func test_designer_added_event_rules_are_subscribed_and_evaluated() -> void:
	var custom_rule: RS_Rule = _make_event_dispatch_rule(
		StringName("designer_event_rule"),
		EVENT_CUSTOM_RULE_TRIGGER,
		StringName("designer/event_rule_fired")
	)
	var fixture: Dictionary = await _create_fixture([custom_rule])
	var store: MockStateStore = fixture["store"] as MockStateStore

	U_ECSEventBus.publish(EVENT_CUSTOM_RULE_TRIGGER, {"entity_id": StringName("player")})
	await _pump()

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1)
	if actions.is_empty():
		return
	assert_eq(actions[0].get("type", StringName()), StringName("designer/event_rule_fired"))

func test_nested_event_name_condition_inside_composite_is_subscribed_and_evaluated() -> void:
	var event_condition := CONDITION_EVENT_NAME.new()
	event_condition.expected_event_name = EVENT_CUSTOM_RULE_TRIGGER

	var literal := CONDITION_CONSTANT.new()
	literal.score = 1.0

	var composite := CONDITION_COMPOSITE.new()
	composite.mode = CONDITION_COMPOSITE.CompositeMode.ANY
	composite.children.clear()
	composite.children.append(literal as I_Condition)
	composite.children.append(event_condition as I_Condition)

	var effect := EFFECT_DISPATCH_ACTION.new()
	effect.action_type = StringName("designer/composite_event_rule_fired")

	var rule := RULE_RESOURCE.new()
	rule.rule_id = StringName("designer_event_rule_composite")
	rule.trigger_mode = "event"
	rule.conditions.clear()
	rule.conditions.append(composite as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)

	var fixture: Dictionary = await _create_fixture([rule])
	var store: MockStateStore = fixture["store"] as MockStateStore

	U_ECSEventBus.publish(EVENT_CUSTOM_RULE_TRIGGER, {"entity_id": StringName("player")})
	await _pump()

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1)
	if actions.is_empty():
		return
	assert_eq(actions[0].get("type", StringName()), StringName("designer/composite_event_rule_fired"))

func test_event_subscription_is_cleaned_up_on_exit_tree() -> void:
	var custom_rule: RS_Rule = _make_event_dispatch_rule(
		StringName("cleanup_rule"),
		EVENT_CUSTOM_RULE_TRIGGER,
		StringName("designer/cleanup_fired")
	)
	var fixture: Dictionary = await _create_fixture([custom_rule])
	var store: MockStateStore = fixture["store"] as MockStateStore
	var system: Variant = fixture["system"]

	U_ECSEventBus.publish(EVENT_CUSTOM_RULE_TRIGGER, {})
	await _pump()
	assert_eq(store.get_dispatched_actions().size(), 1)

	store.clear_dispatched_actions()
	system.queue_free()
	await _pump()

	U_ECSEventBus.publish(EVENT_CUSTOM_RULE_TRIGGER, {})
	await _pump()
	assert_eq(store.get_dispatched_actions().size(), 0)

func test_process_tick_is_no_op_when_all_rules_are_event_only() -> void:
	var fixture: Dictionary = await _create_fixture()
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore

	system.process_tick(0.016)

	assert_eq(store.get_dispatched_actions().size(), 0)
	assert_eq(U_ECSEventBus.get_event_history().size(), 0)

func test_global_tick_context_is_evaluated_when_tick_rule_is_added_via_export() -> void:
	var tick_rule: RS_Rule = _make_tick_dispatch_rule(
		StringName("tick_rule"),
		"gameplay.tick_gate",
		"true",
		StringName("designer/tick_rule_fired")
	)
	var fixture: Dictionary = await _create_fixture([tick_rule])
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore

	store.set_slice(StringName("gameplay"), {"tick_gate": true})
	system.process_tick(0.016)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1)
	if actions.is_empty():
		return
	assert_eq(actions[0].get("type", StringName()), StringName("designer/tick_rule_fired"))

func _create_fixture(designer_rules: Array = []) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	store.set_slice(StringName("gameplay"), {})

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system := GAME_EVENT_SYSTEM.new()
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	add_child(system)

	var typed_rules: Array[RS_Rule] = []
	for rule_variant in designer_rules:
		if rule_variant is RS_Rule:
			typed_rules.append(rule_variant)
	system.rules = typed_rules
	system.configure(ecs_manager)
	await _pump()

	return {
		"system": system,
		"store": store,
		"ecs_manager": ecs_manager,
	}

func _make_event_dispatch_rule(rule_id: StringName, trigger_event: StringName, action_type: StringName) -> RS_Rule:
	var event_condition := CONDITION_EVENT_NAME.new()
	event_condition.expected_event_name = trigger_event

	var effect := EFFECT_DISPATCH_ACTION.new()
	effect.action_type = action_type

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = "event"
	rule.conditions.clear()
	rule.conditions.append(event_condition as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule

func _make_event_publish_rule(
	rule_id: StringName,
	trigger_event: StringName,
	published_event: StringName,
	static_payload: Dictionary = {}
) -> RS_Rule:
	var event_condition := CONDITION_EVENT_NAME.new()
	event_condition.expected_event_name = trigger_event

	var effect := EFFECT_PUBLISH_EVENT.new()
	effect.event_name = published_event
	effect.payload = static_payload.duplicate(true)
	effect.inject_entity_id = true

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = "event"
	rule.conditions.clear()
	rule.conditions.append(event_condition as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule

func _make_tick_dispatch_rule(
	rule_id: StringName,
	state_path: String,
	match_value: String,
	action_type: StringName
) -> RS_Rule:
	var condition := CONDITION_REDUX_FIELD.new()
	condition.state_path = state_path
	condition.match_mode = "equals"
	condition.match_value_string = match_value

	var effect := EFFECT_DISPATCH_ACTION.new()
	effect.action_type = action_type

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = "tick"
	rule.conditions.clear()
	rule.conditions.append(condition as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule

func _find_events_by_name(history: Array, event_name: StringName) -> Array:
	return history.filter(func(entry: Dictionary) -> bool:
		return entry.get("name", StringName()) == event_name
	)

func _pump() -> void:
	await get_tree().process_frame
