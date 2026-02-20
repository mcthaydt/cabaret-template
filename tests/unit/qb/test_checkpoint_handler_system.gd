extends BaseTest

const CHECKPOINT_HANDLER_SYSTEM := preload("res://scripts/ecs/systems/s_checkpoint_handler_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func _pump() -> void:
	await get_tree().process_frame

func _setup_fixture() -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system := CHECKPOINT_HANDLER_SYSTEM.new()
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	add_child(system)
	system.configure(ecs_manager)
	await _pump()

	return {
		"system": system,
		"store": store,
	}

func test_checkpoint_activation_flow_dispatches_state_and_event() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: MockStateStore = fixture["store"] as MockStateStore

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_checkpoint_test"
	add_child(spawn_point)
	autofree(spawn_point)
	await _pump()
	spawn_point.global_position = Vector3(3.0, 4.0, 5.0)

	var checkpoint_entity := Node3D.new()
	checkpoint_entity.name = "E_Checkpoint"
	add_child(checkpoint_entity)
	autofree(checkpoint_entity)

	var checkpoint := C_CheckpointComponent.new()
	checkpoint.checkpoint_id = StringName("cp_test")
	checkpoint.spawn_point_id = StringName("sp_checkpoint_test")
	checkpoint_entity.add_child(checkpoint)
	autofree(checkpoint)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED, {
		"entity_id": StringName("player"),
		"checkpoint": checkpoint,
		"spawn_point_id": checkpoint.spawn_point_id,
	})
	await _pump()

	assert_true(checkpoint.is_activated, "Checkpoint should activate when request event is received")

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Checkpoint activation should dispatch one state action")
	if actions.is_empty():
		return
	assert_eq(actions[0].get("type"), U_GameplayActions.ACTION_SET_LAST_CHECKPOINT)
	assert_eq(actions[0].get("payload"), checkpoint.spawn_point_id)

	var history: Array = U_ECSEventBus.get_event_history()
	var activation_events: Array = history.filter(func(entry: Dictionary) -> bool:
		return entry.get("name") == U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATED
	)
	assert_eq(activation_events.size(), 1, "Checkpoint activation should publish checkpoint_activated")
	if activation_events.is_empty():
		return
	var payload: Dictionary = activation_events[0].get("payload", {})
	assert_eq(payload.get("position"), spawn_point.global_position)

func test_spawn_position_resolution_falls_back_to_zero_when_missing() -> void:
	await _setup_fixture()

	var checkpoint_entity := Node3D.new()
	checkpoint_entity.name = "E_Checkpoint"
	add_child(checkpoint_entity)
	autofree(checkpoint_entity)

	var checkpoint := C_CheckpointComponent.new()
	checkpoint.checkpoint_id = StringName("cp_missing_spawn")
	checkpoint.spawn_point_id = StringName("sp_missing")
	checkpoint_entity.add_child(checkpoint)
	autofree(checkpoint)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED, {
		"checkpoint": checkpoint,
		"spawn_point_id": checkpoint.spawn_point_id,
	})
	await _pump()

	var history: Array = U_ECSEventBus.get_event_history()
	var activation_events: Array = history.filter(func(entry: Dictionary) -> bool:
		return entry.get("name") == U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATED
	)
	assert_eq(activation_events.size(), 1)
	if activation_events.is_empty():
		return
	var payload: Dictionary = activation_events[0].get("payload", {})
	assert_eq(payload.get("position"), Vector3.ZERO, "Missing spawn point should resolve to Vector3.ZERO")
