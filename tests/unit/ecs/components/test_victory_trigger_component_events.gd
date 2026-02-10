extends BaseTest


func before_each() -> void:
	U_ECSEventBus.reset()

func test_publish_victory_events_on_player_enter() -> void:
	var manager := autofree(M_ECSManager.new())
	add_child(manager)
	await get_tree().process_frame

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)

	var player_tag := C_PlayerTagComponent.new()
	entity.add_child(player_tag)

	var trigger := C_VictoryTriggerComponent.new()
	entity.add_child(trigger)

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)

	await wait_physics_frames(2)  # allow deferred registration

	# Clear registration events from setup
	U_ECSEventBus.clear_history()

	trigger._on_body_entered(body)

	var events := U_ECSEventBus.get_event_history()
	var zone_events := events.filter(func(e): return e.get("name") == StringName("victory_zone_entered"))
	var trigger_events := events.filter(func(e): return e.get("name") == StringName("victory_triggered"))

	assert_eq(zone_events.size(), 1, "Should publish zone entered event")
	assert_eq(trigger_events.size(), 1, "Should publish victory triggered event")

	var zone_payload: Dictionary = zone_events[0].get("payload", {})
	# Note: entity_id is derived from body name, not entity name
	assert_eq(zone_payload.get("entity_id"), StringName("body"))
	assert_eq(zone_payload.get("trigger_node"), trigger)
	assert_eq(zone_payload.get("body"), body)

	var trigger_payload: Dictionary = trigger_events[0].get("payload", {})
	# Note: entity_id is derived from body name, not entity name
	assert_eq(trigger_payload.get("entity_id"), StringName("body"))
	assert_eq(trigger_payload.get("trigger_node"), trigger)
	assert_eq(trigger_payload.get("body"), body)

func test_trigger_once_blocks_republish() -> void:
	var manager := autofree(M_ECSManager.new())
	add_child(manager)
	await get_tree().process_frame

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)

	var player_tag := C_PlayerTagComponent.new()
	entity.add_child(player_tag)

	var trigger := C_VictoryTriggerComponent.new()
	entity.add_child(trigger)

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)

	await wait_physics_frames(2)

	# Clear registration events from setup
	U_ECSEventBus.clear_history()

	trigger.set_triggered()
	trigger._on_body_entered(body)

	var events := U_ECSEventBus.get_event_history()
	var zone_events := events.filter(func(e): return e.get("name") == StringName("victory_zone_entered"))
	var trigger_events := events.filter(func(e): return e.get("name") == StringName("victory_triggered"))

	assert_eq(zone_events.size(), 1, "Should still publish zone entered event")
	assert_eq(trigger_events.size(), 0, "Trigger once should block victory_triggered after already triggered")
