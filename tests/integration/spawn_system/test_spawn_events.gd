extends GutTest

## Integration test: M_SpawnManager publishes player_spawned event

const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

var _spawn_manager: M_SpawnManager
var _store: M_StateStore
var _scene: Node3D

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

	_store = M_STATE_STORE.new()
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	_spawn_manager = M_SPAWN_MANAGER.new()
	add_child_autofree(_spawn_manager)
	await get_tree().process_frame

	_scene = Node3D.new()
	_scene.name = "TestSpawnScene"
	add_child_autofree(_scene)

func after_each() -> void:
	_spawn_manager = null
	_store = null
	_scene = null
	U_ECS_EVENT_BUS.reset()

func test_spawn_player_at_point_publishes_player_spawned_event() -> void:
	# Arrange: player and spawn point
	var player := Node3D.new()
	player.name = "E_Player"
	_scene.add_child(player)

	var spawn := Node3D.new()
	spawn.name = "sp_entry"
	spawn.position = Vector3(1, 2, 3)
	_scene.add_child(spawn)

	# Act
	var ok := _spawn_manager.spawn_player_at_point(_scene, StringName("sp_entry"))
	await wait_physics_frames(1)

	# Assert: success and event published with payload
	assert_true(ok, "Spawn should succeed")
	var history: Array = U_ECS_EVENT_BUS.get_event_history()
	var found := false
	for ev in history:
		if ev.get("name") == StringName("player_spawned"):
			var payload: Dictionary = ev.get("payload", {})
			found = payload.get("spawn_point_id", StringName("")) == StringName("sp_entry")
			if found:
				break
	assert_true(found, "Should publish player_spawned event with spawn_point_id")
