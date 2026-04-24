extends GutTest

## Integration test: M_SpawnManager dispatches player_spawned action to Redux

const M_SPAWN_MANAGER := preload("res://scripts/core/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const U_SPAWN_ACTIONS := preload("res://scripts/state/actions/u_spawn_actions.gd")

var _spawn_manager: M_SpawnManager
var _store: M_StateStore
var _scene: Node3D

func before_each() -> void:
	_store = M_STATE_STORE.new()
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
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
	U_ServiceLocator.clear()

func test_spawn_player_at_point_dispatches_player_spawned_action() -> void:
	# Arrange: player and spawn point
	var player := Node3D.new()
	player.name = "E_Player"
	_scene.add_child(player)

	var spawn := Node3D.new()
	spawn.name = "sp_entry"
	spawn.position = Vector3(1, 2, 3)
	_scene.add_child(spawn)

	# Channel taxonomy: observe player_spawned via Redux action_dispatched
	var action_received: Array = [false]
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		if action.get("type", StringName("")) == U_SPAWN_ACTIONS.ACTION_PLAYER_SPAWNED:
			action_received[0] = true
	)

	# Act
	var ok := _spawn_manager.spawn_player_at_point(_scene, StringName("sp_entry"))
	await wait_physics_frames(1)

	# Assert: success and action dispatched
	assert_true(ok, "Spawn should succeed")
	assert_true(action_received[0], "Should dispatch player_spawned action to Redux")