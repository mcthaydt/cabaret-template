extends BaseTest

const GAME_RULE_MANAGER := preload("res://scripts/ecs/systems/s_game_rule_manager.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func _create_system(rules: Array = []) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system := GAME_RULE_MANAGER.new()
	autofree(system)
	system.rule_definitions = rules
	system.state_store = store
	system.ecs_manager = ecs_manager
	add_child(system)
	system.configure(ecs_manager)

	return {
		"system": system,
		"store": store,
	}

func _make_publish_rule(rule_id: StringName, trigger_event: StringName, target_event: StringName) -> Variant:
	var effect := QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.PUBLISH_EVENT
	effect.target = String(target_event)
	effect.payload = {}

	var rule := QB_RULE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = QB_RULE.TriggerMode.EVENT
	rule.trigger_event = trigger_event
	rule.effects = [effect]
	rule.requires_salience = true
	return rule

func test_checkpoint_rule_forwards_event_payload_via_publish_event() -> void:
	var fixture: Dictionary = _create_system([
		_make_publish_rule(
			StringName("checkpoint_rule"),
			U_ECSEventNames.EVENT_CHECKPOINT_ZONE_ENTERED,
			U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED
		)
	])
	var system: Variant = fixture["system"]
	assert_false(system.call("get_registered_rule_ids").is_empty())

	var checkpoint := C_CheckpointComponent.new()
	autofree(checkpoint)
	checkpoint.checkpoint_id = StringName("cp_test")
	checkpoint.spawn_point_id = StringName("sp_test")

	var checkpoint_entity := Node3D.new()
	checkpoint_entity.name = "E_Checkpoint"
	add_child(checkpoint_entity)
	autofree(checkpoint_entity)
	checkpoint_entity.add_child(checkpoint)

	var body := Node3D.new()
	add_child(body)
	autofree(body)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_CHECKPOINT_ZONE_ENTERED, {
		"entity_id": StringName("player"),
		"checkpoint": checkpoint,
		"spawn_point_id": checkpoint.spawn_point_id,
		"body": body,
	})

	var history: Array = U_ECSEventBus.get_event_history()
	var forwarded_events: Array = history.filter(func(entry: Dictionary) -> bool:
		return entry.get("name") == U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED
	)
	assert_eq(forwarded_events.size(), 1)
	if forwarded_events.is_empty():
		return
	var forwarded_payload: Dictionary = forwarded_events[0].get("payload", {})
	assert_eq(forwarded_payload.get("entity_id"), StringName("player"))
	assert_eq(forwarded_payload.get("checkpoint"), checkpoint)
	assert_eq(forwarded_payload.get("spawn_point_id"), checkpoint.spawn_point_id)

func test_victory_rule_forwards_event_payload_via_publish_event() -> void:
	var fixture: Dictionary = _create_system([
		_make_publish_rule(
			StringName("victory_rule"),
			U_ECSEventNames.EVENT_VICTORY_TRIGGERED,
			U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED
		)
	])
	var system: Variant = fixture["system"]
	assert_false(system.call("get_registered_rule_ids").is_empty())

	var trigger_entity := Node3D.new()
	add_child(trigger_entity)
	autofree(trigger_entity)
	var trigger := C_VictoryTriggerComponent.new()
	autofree(trigger)
	trigger_entity.add_child(trigger)

	var body := Node3D.new()
	add_child(body)
	autofree(body)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_VICTORY_TRIGGERED, {
		"entity_id": StringName("player"),
		"trigger_node": trigger,
		"body": body,
	})

	var history: Array = U_ECSEventBus.get_event_history()
	var forwarded_events: Array = history.filter(func(entry: Dictionary) -> bool:
		return entry.get("name") == U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED
	)
	assert_eq(forwarded_events.size(), 1)
	if forwarded_events.is_empty():
		return
	var forwarded_payload: Dictionary = forwarded_events[0].get("payload", {})
	assert_eq(forwarded_payload.get("entity_id"), StringName("player"))
	assert_eq(forwarded_payload.get("trigger_node"), trigger)
	assert_eq(forwarded_payload.get("body"), body)
