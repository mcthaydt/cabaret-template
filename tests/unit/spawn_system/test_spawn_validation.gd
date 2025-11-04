extends GutTest

## Unit tests for M_SpawnManager validation logic (T218)
##
## Tests edge cases, error handling, and validation for spawn operations.

const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")

var spawn_manager: M_SPAWN_MANAGER
var state_store: M_STATE_STORE
var test_scene: Node3D

func before_each() -> void:
	# Create state store
	state_store = M_STATE_STORE.new()
	state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	add_child_autofree(state_store)
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

## ============================================================================
## Edge Case Tests
## ============================================================================

func test_spawn_fails_gracefully_with_null_scene() -> void:
	# Act
	var result: bool = spawn_manager.spawn_player_at_point(null, StringName("sp_test"))

	# Assert
	assert_push_error("Cannot spawn player - scene is null")
	assert_false(result, "Should fail gracefully with null scene")

func test_spawn_fails_gracefully_with_empty_spawn_point_id() -> void:
	# Arrange
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName(""))

	# Assert
	assert_push_error("Cannot spawn player - spawn_point_id is empty")
	assert_false(result, "Should fail with empty spawn point ID")

func test_spawn_handles_player_with_different_node_types() -> void:
	# Arrange: Test with different Node3D-based player types
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	spawn_point.position = Vector3(10, 5, 0)
	test_scene.add_child(spawn_point)

	# Test with CharacterBody3D
	var player_char_body := CharacterBody3D.new()
	player_char_body.name = "E_Player"
	test_scene.add_child(player_char_body)

	# Act
	var result1: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_true(result1, "Should work with CharacterBody3D player")
	assert_almost_eq(player_char_body.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01))

	# Clean up and test with RigidBody3D
	test_scene.remove_child(player_char_body)
	player_char_body.queue_free()
	await get_tree().process_frame

	var player_rigid_body := RigidBody3D.new()
	player_rigid_body.name = "E_Player"
	test_scene.add_child(player_rigid_body)

	# Act
	var result2: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_true(result2, "Should work with RigidBody3D player")
	assert_almost_eq(player_rigid_body.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01))

func test_spawn_with_spawn_point_at_world_origin() -> void:
	# Arrange
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_origin"
	spawn_point.position = Vector3.ZERO
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.position = Vector3(100, 100, 100)
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_origin"))

	# Assert
	assert_true(result)
	assert_almost_eq(player.global_position, Vector3.ZERO, Vector3(0.01, 0.01, 0.01), "Should spawn at origin correctly")

## ============================================================================
## Type Validation Tests
## ============================================================================

func test_spawn_rejects_control_node_as_spawn_point() -> void:
	# Arrange: Spawn point is a Control node (not Node3D)
	var spawn_point := Control.new()
	spawn_point.name = "sp_invalid"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_invalid"))

	# Assert
	assert_push_error("is not a Node3D (found type: Control)")
	assert_false(result, "Should reject Control node as spawn point")

func test_spawn_rejects_plain_node_as_spawn_point() -> void:
	# Arrange: Spawn point is a plain Node (not Node3D)
	var spawn_point := Node.new()
	spawn_point.name = "sp_invalid"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_invalid"))

	# Assert
	assert_push_error("is not a Node3D (found type: Node)")
	assert_false(result, "Should reject plain Node as spawn point")

func test_spawn_accepts_node3d_derived_types_as_spawn_points() -> void:
	# Arrange: Test various Node3D-derived types
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Test with Marker3D
	var spawn_marker := Marker3D.new()
	spawn_marker.name = "sp_marker"
	spawn_marker.position = Vector3(5, 0, 0)
	test_scene.add_child(spawn_marker)

	var result1: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_marker"))
	assert_true(result1, "Should accept Marker3D as spawn point")

	# Test with MeshInstance3D (unusual but valid Node3D)
	var spawn_mesh := MeshInstance3D.new()
	spawn_mesh.name = "sp_mesh"
	spawn_mesh.position = Vector3(10, 0, 0)
	test_scene.add_child(spawn_mesh)

	var result2: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_mesh"))
	assert_true(result2, "Should accept MeshInstance3D as spawn point")

## ============================================================================
## Player Entity Discovery Tests
## ============================================================================

func test_spawn_fails_when_multiple_players_exist() -> void:
	# Arrange: Multiple player entities
	var player1 := CharacterBody3D.new()
	player1.name = "E_Player1"
	test_scene.add_child(player1)

	var player2 := CharacterBody3D.new()
	player2.name = "E_Player2"
	test_scene.add_child(player2)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	# Act: Should use first player found
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert: Should succeed but only position one player
	assert_true(result, "Should handle multiple players by using first match")

func test_spawn_ignores_nodes_without_e_player_prefix() -> void:
	# Arrange: Various entities, none are players
	var enemy := Node3D.new()
	enemy.name = "E_Enemy"
	test_scene.add_child(enemy)

	var npc := Node3D.new()
	npc.name = "E_NPC"
	test_scene.add_child(npc)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_push_error("M_SpawnManager: Player entity not found")
	assert_false(result, "Should not find player without E_Player prefix")

func test_spawn_matches_e_player_prefix_case_sensitive() -> void:
	# Arrange: Node with lowercase prefix
	var fake_player := CharacterBody3D.new()
	fake_player.name = "e_player"  # lowercase
	test_scene.add_child(fake_player)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_push_error("M_SpawnManager: Player entity not found")
	assert_false(result, "Should require exact 'E_Player' prefix (case-sensitive)")

## ============================================================================
## Scene Tree Search Tests
## ============================================================================

func test_spawn_searches_entire_subtree_not_just_immediate_children() -> void:
	# Arrange: Nested structure
	var entities_group := Node3D.new()
	entities_group.name = "Entities"
	test_scene.add_child(entities_group)

	var player_container := Node3D.new()
	player_container.name = "PlayerContainer"
	entities_group.add_child(player_container)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player_container.add_child(player)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	test_scene.add_child(spawn_points)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_nested"
	spawn_point.position = Vector3(15, 0, 0)
	spawn_points.add_child(spawn_point)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_nested"))

	# Assert
	assert_true(result, "Should find deeply nested nodes")
	assert_almost_eq(player.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01))

## ============================================================================
## Error Message Quality Tests
## ============================================================================

func test_spawn_error_includes_scene_name_when_spawn_point_missing() -> void:
	# Arrange
	test_scene.name = "TestSceneWithLongName"
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_missing"))

	# Assert
	assert_push_error("Spawn point 'sp_missing' not found in scene 'TestSceneWithLongName'")

func test_spawn_error_includes_scene_name_when_player_missing() -> void:
	# Arrange
	test_scene.name = "EmptyTestScene"
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_push_error("Player entity not found in scene 'EmptyTestScene'")

func test_spawn_error_includes_node_type_when_spawn_point_wrong_type() -> void:
	# Arrange
	var spawn_point := Control.new()
	spawn_point.name = "sp_control"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_control"))

	# Assert
	assert_push_error("found type: Control")
