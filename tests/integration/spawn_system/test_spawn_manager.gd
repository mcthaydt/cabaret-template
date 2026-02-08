extends GutTest

## Integration tests for M_SpawnManager (T217)
##
## Tests spawn point discovery, player positioning, and validation logic
## in realistic scene configurations.

const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const SP_SPAWN_POINT := preload("res://scripts/scene_management/sp_spawn_point.gd")
const RS_SPAWN_METADATA := preload("res://scripts/resources/scene_management/rs_spawn_metadata.gd")

var spawn_manager: M_SpawnManager
var state_store: M_StateStore
var test_scene: Node3D

func before_each() -> void:
	# Create state store with gameplay initial state
	state_store = M_STATE_STORE.new()
	state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	add_child_autofree(state_store)
	U_ServiceLocator.register(StringName("state_store"), state_store)
	await get_tree().process_frame

	# Create spawn manager
	spawn_manager = M_SPAWN_MANAGER.new()
	add_child_autofree(spawn_manager)
	await get_tree().process_frame

	# Create test scene
	test_scene = Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)

func after_each() -> void:
	if spawn_manager and is_instance_valid(spawn_manager):
		spawn_manager.queue_free()
	if state_store and is_instance_valid(state_store):
		state_store.queue_free()
	if test_scene and is_instance_valid(test_scene):
		test_scene.queue_free()
	U_ServiceLocator.clear()

func _project_onto_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	var normal := plane_normal.normalized()
	if normal.length() == 0.0:
		return Vector3.ZERO
	return vector - normal * vector.dot(normal)

## ============================================================================
## Spawn Point Discovery Tests
## ============================================================================

func test_spawn_player_at_point_finds_spawn_point_by_name() -> void:
	# Arrange: Create spawn point
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test_spawn"
	spawn_point.position = Vector3(10, 5, 8)
	test_scene.add_child(spawn_point)

	# Create player entity
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	assert_true(result, "Spawn should succeed")
	assert_almost_eq(player.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01), "Player should be positioned at spawn point")

func test_spawn_player_at_point_fails_when_spawn_point_missing() -> void:
	# Arrange: Create player but no spawn point
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_nonexistent"))

	# Assert
	assert_push_error("M_SpawnManager: Spawn point 'sp_nonexistent' not found")
	assert_false(result, "Spawn should fail when spawn point missing")

func test_spawn_player_at_point_fails_when_player_missing() -> void:
	# Arrange: Create spawn point but no player
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test_spawn"
	test_scene.add_child(spawn_point)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	assert_push_error("M_SpawnManager: Player entity not found")
	assert_false(result, "Spawn should fail when player missing")

func test_spawn_player_at_point_validates_spawn_point_is_node3d() -> void:
	# Arrange: Create spawn point that's not a Node3D
	var spawn_point := Node.new()  # Plain Node, not Node3D
	spawn_point.name = "sp_test_spawn"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	assert_push_error("is not a Node3D (found type: Node)")
	assert_false(result, "Spawn should fail when spawn point is not Node3D")

## ============================================================================
## Player Positioning Tests
## ============================================================================

func test_spawn_positions_player_at_spawn_point_global_position() -> void:
	# Arrange: Create nested spawn point
	var container := Node3D.new()
	container.position = Vector3(100, 50, 75)
	test_scene.add_child(container)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test_spawn"
	spawn_point.position = Vector3(10, 5, 8)  # Relative to container
	container.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	assert_true(result)
	var expected_position := Vector3(110, 55, 83)  # container + spawn_point
	assert_almost_eq(player.global_position, expected_position, Vector3(0.01, 0.01, 0.01), "Player should use spawn point global position")

func test_spawn_applies_spawn_point_rotation_to_player() -> void:
	# Arrange
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test_spawn"
	spawn_point.rotation_degrees = Vector3(0, 90, 0)  # Face east
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.rotation_degrees = Vector3(0, 0, 0)  # Face north initially
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	assert_almost_eq(player.global_rotation, spawn_point.global_rotation, Vector3(0.01, 0.01, 0.01), "Player should inherit spawn point rotation")

func test_spawn_faces_active_camera_when_metadata_requests() -> void:
	# Arrange: active camera
	var camera := Camera3D.new()
	camera.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	camera.current = true
	test_scene.add_child(camera)
	autofree(camera)

	# Arrange: spawn point with metadata flag
	var spawn_point := SP_SPAWN_POINT.new()
	spawn_point.name = "sp_test_spawn"
	var metadata := RS_SPAWN_METADATA.new()
	metadata.spawn_id = StringName("sp_test_spawn")
	metadata.face_camera_on_spawn = true
	spawn_point.spawn_metadata = metadata
	test_scene.add_child(spawn_point)
	autofree(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	var cam_forward := -camera.global_transform.basis.z
	cam_forward = _project_onto_plane(cam_forward, Vector3.UP)
	cam_forward = cam_forward.normalized()
	var expected: float = atan2(-cam_forward.x, -cam_forward.z)
	assert_almost_eq(wrapf(player.global_rotation.y, -PI, PI), expected, 0.001, "Player should face camera yaw on spawn")

func test_spawn_finds_player_by_e_player_prefix() -> void:
	# Arrange: Multiple entities, only one is player
	var enemy := Node3D.new()
	enemy.name = "E_Enemy"
	test_scene.add_child(enemy)

	var player := CharacterBody3D.new()
	player.name = "E_PlayerCharacter"  # Has E_Player prefix
	test_scene.add_child(player)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test_spawn"
	spawn_point.position = Vector3(5, 0, 5)
	test_scene.add_child(spawn_point)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test_spawn"))

	# Assert
	assert_true(result)
	assert_almost_eq(player.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01), "Should find player by E_Player prefix")

## ============================================================================
## Spawn Point Search Tests
## ============================================================================

func test_spawn_searches_nested_scene_tree_for_spawn_points() -> void:
	# Arrange: Deeply nested spawn point
	var level1 := Node3D.new()
	level1.name = "Level1"
	test_scene.add_child(level1)

	var level2 := Node3D.new()
	level2.name = "Level2"
	level1.add_child(level2)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_deep_spawn"
	spawn_point.position = Vector3(20, 10, 15)
	level2.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_deep_spawn"))

	# Assert
	assert_true(result, "Should find deeply nested spawn point")

func test_spawn_prefers_first_match_when_duplicate_spawn_names() -> void:
	# Arrange: Two spawn points with same name
	var spawn1 := Node3D.new()
	spawn1.name = "sp_duplicate"
	spawn1.position = Vector3(10, 0, 0)
	test_scene.add_child(spawn1)

	var spawn2 := Node3D.new()
	spawn2.name = "sp_duplicate"
	spawn2.position = Vector3(50, 0, 0)
	test_scene.add_child(spawn2)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_duplicate"))

	# Assert: Should use first spawn point found
	var distance_to_spawn1 := player.global_position.distance_to(spawn1.global_position)
	assert_lt(distance_to_spawn1, 0.1, "Should spawn at first matching spawn point")
