extends GutTest

## Test Spawn Point Validation (T210)
##
## Verifies that M_SceneManager properly validates spawn points before positioning
## the player, preventing configuration errors from causing invisible bugs.
##
## **Phase 11 improvements** (T207):
## - Missing spawn point logs push_error (not push_warning)
## - Invalid spawn point type (non-Node3D) caught and logged
## - Scene name included in error messages for easier debugging

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

var _scene_manager: M_SceneManager
var _state_store: M_StateStore
var _test_scene_root: Node

func before_each() -> void:
	# Create root scene with required containers
	_test_scene_root = Node.new()
	_test_scene_root.name = "TestRoot"
	add_child_autofree(_test_scene_root)

	# Add required containers
	var active_scene_container := Node.new()
	active_scene_container.name = "ActiveSceneContainer"
	_test_scene_root.add_child(active_scene_container)

	var ui_overlay_stack := CanvasLayer.new()
	ui_overlay_stack.name = "UIOverlayStack"
	_test_scene_root.add_child(ui_overlay_stack)

	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	_test_scene_root.add_child(transition_overlay)

	var loading_overlay := CanvasLayer.new()
	loading_overlay.name = "LoadingOverlay"
	_test_scene_root.add_child(loading_overlay)

	# Create state store
	_state_store = M_StateStore.new()
	_state_store.name = "M_StateStore"
	var scene_initial_state := preload("res://scripts/state/resources/rs_scene_initial_state.gd").new()
	var gameplay_initial_state := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd").new()
	_state_store.scene_initial_state = scene_initial_state
	_state_store.gameplay_initial_state = gameplay_initial_state
	add_child_autofree(_state_store)

	# Wait for state store to initialize
	await get_tree().process_frame

	# Create scene manager
	_scene_manager = M_SceneManager.new()
	_scene_manager.name = "M_SceneManager"
	_scene_manager.skip_initial_scene_load = true
	add_child_autofree(_scene_manager)

	# Wait for scene manager to initialize
	await get_tree().process_frame

func after_each() -> void:
	# Cleanup is handled by autofree
	pass

## Test: Missing spawn point logs error and doesn't spawn player
func test_missing_spawn_point_logs_error() -> void:
	# Create test scene with player but NO spawn point
	var test_scene := Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)  # Add to tree FIRST

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)
	player.global_position = Vector3(5, 5, 5)  # Set after in tree

	# Set target spawn point in state
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_nonexistent")))

	# Call restore spawn point
	_scene_manager._restore_player_spawn_point(test_scene)

	# Assert the expected error was logged
	assert_push_error("M_SceneManager: Spawn point 'sp_nonexistent' not found")

	# Verify player was NOT moved (remains at original position)
	assert_eq(player.global_position, Vector3(5, 5, 5), "Player should not move when spawn point missing")

	# Verify spawn point was cleared from state
	var state := _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_true(target_spawn.is_empty(), "Target spawn point should be cleared after failed spawn")

## Test: Invalid spawn point type (non-Node3D) handled gracefully
func test_invalid_spawn_point_type_logs_error() -> void:
	# Create test scene with player and Node (not Node3D) as spawn point
	var test_scene := Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)  # Add to tree FIRST

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)
	player.global_position = Vector3(5, 5, 5)

	# Add spawn point as plain Node (not Node3D)
	var spawn_point := Node.new()  # Wrong type!
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	# Set target spawn point in state
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_test")))

	# Call restore spawn point
	_scene_manager._restore_player_spawn_point(test_scene)

	# Assert the expected error was logged
	assert_push_error("M_SceneManager: Spawn point 'sp_test' in scene 'TestScene' is not a Node3D")

	# Verify player was NOT moved
	assert_eq(player.global_position, Vector3(5, 5, 5), "Player should not move when spawn point is wrong type")

	# Verify spawn point was cleared
	var state := _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_true(target_spawn.is_empty(), "Target spawn point should be cleared after type validation failure")

## Test: Valid spawn point works correctly
func test_valid_spawn_point_positions_player() -> void:
	# Create test scene with player and valid Node3D spawn point
	var test_scene := Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)  # Add to tree FIRST

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)
	player.global_position = Vector3(5, 5, 5)
	player.global_rotation = Vector3.ZERO

	# Add valid spawn point (Node3D)
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_entrance"
	test_scene.add_child(spawn_point)
	spawn_point.global_position = Vector3(10, 2, 15)
	spawn_point.global_rotation = Vector3(0, PI/2, 0)  # 90 degree rotation

	# Set target spawn point in state
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_entrance")))

	# Call restore spawn point
	_scene_manager._restore_player_spawn_point(test_scene)

	# Verify player was moved to spawn point
	assert_almost_eq(player.global_position, Vector3(10, 2, 15), Vector3(0.01, 0.01, 0.01), "Player should be at spawn point position")
	assert_almost_eq(player.global_rotation, Vector3(0, PI/2, 0), Vector3(0.01, 0.01, 0.01), "Player should match spawn point rotation")

	# Verify spawn point was cleared
	var state := _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_true(target_spawn.is_empty(), "Target spawn point should be cleared after successful spawn")

## Test: Spawn point in nested hierarchy works
func test_spawn_point_in_nested_hierarchy() -> void:
	# Create test scene with nested hierarchy
	var test_scene := Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)  # Add to tree FIRST

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)
	player.global_position = Vector3.ZERO

	# Add spawn point deeply nested in hierarchy
	var environment := Node3D.new()
	environment.name = "Environment"
	test_scene.add_child(environment)

	var spawn_markers := Node3D.new()
	spawn_markers.name = "SpawnMarkers"
	environment.add_child(spawn_markers)

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_nested"
	spawn_markers.add_child(spawn_point)
	spawn_point.global_position = Vector3(20, 3, 25)

	# Wait for scene tree to propagate transforms
	await get_tree().process_frame

	# Set target spawn point in state
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_nested")))

	# Call restore spawn point
	_scene_manager._restore_player_spawn_point(test_scene)

	# Verify player was moved to nested spawn point
	assert_almost_eq(player.global_position, Vector3(20, 3, 25), Vector3(0.01, 0.01, 0.01), "Player should find spawn point in nested hierarchy")

## Test: No spawn point specified (normal transition) doesn't move player
func test_no_spawn_point_specified_skips_restoration() -> void:
	# Create test scene with player
	var test_scene := Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)  # Add to tree FIRST

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)
	player.global_position = Vector3(7, 1, 9)

	# Do NOT set target spawn point (normal scene transition)
	# State should have empty spawn point by default

	# Call restore spawn point
	_scene_manager._restore_player_spawn_point(test_scene)

	# Verify player was NOT moved (spawn restoration skipped)
	assert_eq(player.global_position, Vector3(7, 1, 9), "Player should remain at scene-defined position when no spawn point specified")

## Test: Missing player entity logs error
func test_missing_player_entity_logs_error() -> void:
	# Create test scene with spawn point but NO player
	var test_scene := Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)  # Add to tree FIRST

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)
	spawn_point.global_position = Vector3(10, 2, 10)

	# Set target spawn point in state
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_test")))

	# Call restore spawn point
	_scene_manager._restore_player_spawn_point(test_scene)

	# Assert the expected error was logged (checks for substring match)
	assert_push_error("Player entity not found in scene 'TestScene'")

	# Verify spawn point was cleared even though no player found
	var state := _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_true(target_spawn.is_empty(), "Target spawn point should be cleared when player not found")
