extends BaseTest


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
	checkpoint.checkpoint_id = StringName("cp_test")
	checkpoint.spawn_point_id = StringName("sp_test")
	entity.add_child(checkpoint)

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)

	await wait_physics_frames(2)

	# Clear registration events from setup
	U_ECSEventBus.clear_history()

	checkpoint._on_area_body_entered(body)

	var events := U_ECSEventBus.get_event_history()
	var zone_events := events.filter(func(e): return e.get("name") == StringName("checkpoint_zone_entered"))
	assert_eq(zone_events.size(), 1, "Zone enter should publish one event")
	var payload: Dictionary = zone_events[0].get("payload", {})
	assert_eq(payload.get("checkpoint"), checkpoint)
	assert_eq(payload.get("body"), body)
	# Note: entity_id is derived from body name, not entity name
	assert_eq(payload.get("entity_id"), StringName("body"))
