extends BaseTest

const S_CheckpointSystem := preload("res://scripts/ecs/systems/s_checkpoint_system.gd")
const C_CheckpointComponent := preload("res://scripts/ecs/components/c_checkpoint_component.gd")
const C_PlayerTagComponent := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_GameplaySelectors := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_checkpoint_event_updates_last_checkpoint_and_dispatches_activation() -> void:
	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await get_tree().process_frame

	var system := S_CheckpointSystem.new()
	add_child_autofree(system)
	await get_tree().process_frame
	# on_configured() is automatically called by BaseECSSystem.configure()

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)

	var player_tag := C_PlayerTagComponent.new()
	entity.add_child(player_tag)

	var checkpoint := C_CheckpointComponent.new()
	checkpoint.checkpoint_id = StringName("checkpoint_1")
	checkpoint.spawn_point_id = StringName("sp_test")
	entity.add_child(checkpoint)

	await wait_physics_frames(2)

	U_ECSEventBus.publish(StringName("checkpoint_zone_entered"), {
		"entity_id": StringName("player"),
		"checkpoint": checkpoint,
		"body": entity,
		"spawn_point_id": checkpoint.spawn_point_id,
	})
	await wait_physics_frames(2)

	var state := store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var last_checkpoint := U_GameplaySelectors.get_last_checkpoint(gameplay_state)
	assert_eq(last_checkpoint, StringName("sp_test"), "Checkpoint event should update last checkpoint")

	var history := U_ECSEventBus.get_event_history()
	assert_true(history.any(func(event): return event.get("name") == StringName("checkpoint_activated")),
		"Activation event should be published")
