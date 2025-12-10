extends BaseTest

const C_CheckpointComponent := preload("res://scripts/ecs/components/c_checkpoint_component.gd")
const C_PlayerTagComponent := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_checkpoint_publishes_zone_entered_for_player() -> void:
	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)

	var player_tag := C_PlayerTagComponent.new()
	entity.add_child(player_tag)

	var checkpoint := C_CheckpointComponent.new()
	entity.add_child(checkpoint)

	var body := CharacterBody3D.new()
	entity.add_child(body)

	await wait_physics_frames(2)

	checkpoint._on_area_body_entered(body)

	var events := U_ECSEventBus.get_event_history()
	assert_eq(events.size(), 1, "Zone enter should publish one event")
	assert_eq(events[0].get("name"), StringName("checkpoint_zone_entered"))
	var payload: Dictionary = events[0].get("payload", {})
	assert_eq(payload.get("checkpoint"), checkpoint)
	assert_eq(payload.get("body"), body)
	assert_eq(payload.get("entity_id"), StringName("player"))
