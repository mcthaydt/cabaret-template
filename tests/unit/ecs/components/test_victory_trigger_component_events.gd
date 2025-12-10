extends BaseTest

const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const C_VictoryTriggerComponent := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")
const C_PlayerTagComponent := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")

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

	trigger._on_body_entered(body)

	var events := U_ECSEventBus.get_event_history()
	assert_eq(events.size(), 2, "Entering should publish zone + triggered events")

	var zone_event: Dictionary = events[0]
	assert_eq(zone_event.get("name"), StringName("victory_zone_entered"))
	var zone_payload: Dictionary = zone_event.get("payload", {})
	assert_eq(zone_payload.get("entity_id"), StringName("player"))
	assert_eq(zone_payload.get("trigger_node"), trigger)
	assert_eq(zone_payload.get("body"), body)

	var trigger_event: Dictionary = events[1]
	assert_eq(trigger_event.get("name"), StringName("victory_triggered"))
	var trigger_payload: Dictionary = trigger_event.get("payload", {})
	assert_eq(trigger_payload.get("entity_id"), StringName("player"))
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
	entity.add_child(body)

	await wait_physics_frames(2)

	trigger.set_triggered()
	trigger._on_body_entered(body)

	var events := U_ECSEventBus.get_event_history()
	assert_eq(events.size(), 1, "Trigger once should only publish zone entered after triggered")
	assert_eq(events[0].get("name"), StringName("victory_zone_entered"))
