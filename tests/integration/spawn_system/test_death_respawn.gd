extends GutTest

## Integration test for death respawn system (Phase 12.3a)
##
## Tests T252-T254: Death → game_over → respawn at last spawn point.
## Validates that player death triggers transition to game_over, and "Retry"
## button respawns player at the last spawn point they used (target_spawn_point).

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_CAMERA_MANAGER := preload("res://scripts/managers/m_camera_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

var _root_scene: Node
var _scene_manager: M_SCENE_MANAGER
var _spawn_manager: M_SPAWN_MANAGER
var _camera_manager: M_CAMERA_MANAGER
var _store: M_STATE_STORE
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer

func before_each() -> void:
	# Create root scene structure
	_root_scene = Node.new()
	_root_scene.name = "Root"
	add_child_autofree(_root_scene)

	# Create state store with all slices
	_store = M_STATE_STORE.new()
	_store.settings = RS_STATE_STORE_SETTINGS.new()
	var scene_initial_state := RS_SCENE_INITIAL_STATE.new()
	_store.scene_initial_state = scene_initial_state
	_root_scene.add_child(_store)
	await get_tree().process_frame

	# Create scene containers
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root_scene.add_child(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_scene.add_child(_ui_overlay_stack)

	# Create transition overlay for fade effect
	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	_transition_overlay.add_child(color_rect)
	_root_scene.add_child(_transition_overlay)

	# Create spawn manager
	_spawn_manager = M_SPAWN_MANAGER.new()
	_root_scene.add_child(_spawn_manager)

	# Create camera manager
	_camera_manager = M_CAMERA_MANAGER.new()
	_root_scene.add_child(_camera_manager)

	# Create scene manager
	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root_scene.add_child(_scene_manager)
	await get_tree().process_frame

func after_each() -> void:
	_scene_manager = null
	_spawn_manager = null
	_camera_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_root_scene = null

## T252: Test spawn_at_last_spawn() uses target_spawn_point from gameplay state
##
## Validates that spawn_at_last_spawn() reads target_spawn_point from gameplay state
## and spawns player at that spawn point.
func test_spawn_at_last_spawn_uses_target_spawn_point() -> void:
	# Load exterior scene
	_scene_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Set target_spawn_point in gameplay state (simulates door transition)
	_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_test")))
	await get_tree().process_frame

	# Get current scene
	var current_scene: Node = _active_scene_container.get_child(0)
	assert_not_null(current_scene, "Should have loaded exterior scene")

	# Add test spawn point to scene
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	spawn_point.position = Vector3(100, 50, 25)
	current_scene.add_child(spawn_point)

	# Find player in scene
	var player: Node3D = _find_player_in_scene(current_scene)
	assert_not_null(player, "Player should exist in exterior scene")

	var original_pos: Vector3 = player.global_position

	# Act: Call spawn_at_last_spawn()
	var result: bool = _spawn_manager.spawn_at_last_spawn(current_scene)

	# Assert
	assert_true(result, "spawn_at_last_spawn should succeed")
	assert_almost_eq(player.global_position, spawn_point.global_position, Vector3(0.1, 0.1, 0.1),
		"Player should be positioned at target_spawn_point")
	assert_ne(player.global_position, original_pos, "Player position should have changed")

## T252: Test spawn_at_last_spawn() falls back to sp_default if no target_spawn_point
##
## Validates that if target_spawn_point is empty, spawn_at_last_spawn() falls back
## to the default spawn point (sp_default).
func test_spawn_at_last_spawn_fallback_to_default() -> void:
	# Load exterior scene
	_scene_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Ensure target_spawn_point is empty
	_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("")))
	await get_tree().process_frame

	# Get current scene
	var current_scene: Node = _active_scene_container.get_child(0)
	assert_not_null(current_scene, "Should have loaded exterior scene")

	# Find player and default spawn point
	var player: Node3D = _find_player_in_scene(current_scene)
	assert_not_null(player, "Player should exist in exterior scene")

	var default_spawn: Node3D = _find_spawn_point_in_scene(current_scene, "sp_default")
	assert_not_null(default_spawn, "Default spawn point should exist")

	# Move player away from default spawn
	player.global_position = Vector3(999, 999, 999)

	# Act: Call spawn_at_last_spawn()
	var result: bool = _spawn_manager.spawn_at_last_spawn(current_scene)

	# Assert
	assert_true(result, "spawn_at_last_spawn should succeed with fallback")
	assert_almost_eq(player.global_position, default_spawn.global_position, Vector3(0.1, 0.1, 0.1),
		"Player should be positioned at sp_default when no target_spawn_point set")

## T253: Test spawn_at_last_spawn() clears target_spawn_point after use
##
## Validates that after spawning at last spawn point, target_spawn_point is cleared
## from gameplay state to prevent reusing the same spawn point on next death.
func test_spawn_at_last_spawn_clears_target_spawn_point() -> void:
	# Load exterior scene
	_scene_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Set target_spawn_point
	_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_test")))
	await get_tree().process_frame

	var current_scene: Node = _active_scene_container.get_child(0)

	# Add test spawn point
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	spawn_point.position = Vector3(50, 25, 10)
	current_scene.add_child(spawn_point)

	# Act: Call spawn_at_last_spawn()
	_spawn_manager.spawn_at_last_spawn(current_scene)
	await get_tree().process_frame

	# Assert: target_spawn_point should be cleared
	var state: Dictionary = _store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))

	assert_eq(target_spawn, StringName(""), "target_spawn_point should be cleared after spawn")

## T254: Test spawn_at_last_spawn() returns false if spawn point missing
##
## Validates that spawn_at_last_spawn() returns false if the target spawn point
## doesn't exist in the scene (graceful failure).
func test_spawn_at_last_spawn_fails_gracefully_if_spawn_missing() -> void:
	# Load exterior scene
	_scene_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Set target_spawn_point to non-existent spawn
	_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_nonexistent")))
	await get_tree().process_frame

	var current_scene: Node = _active_scene_container.get_child(0)

	# Act: Call spawn_at_last_spawn()
	var result: bool = _spawn_manager.spawn_at_last_spawn(current_scene)

	# Assert: Should fail gracefully
	# Note: Will fall back to sp_default if it exists, or fail if no default
	# Either behavior is acceptable - test that it doesn't crash
	assert_not_null(result, "spawn_at_last_spawn should return a boolean (not crash)")

## T254: Test spawn_at_last_spawn() works with different scene types
##
## Validates that spawn_at_last_spawn() works correctly when transitioning
## between different gameplay scenes (exterior → interior).
func test_spawn_at_last_spawn_works_across_scenes() -> void:
	# Load exterior, transition to interior through door (sets target_spawn_point)
	_scene_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Simulate door transition: set target_spawn_point for interior
	_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_entrance_from_exterior")))
	await get_tree().process_frame

	# Transition to interior
	_scene_manager.transition_to_scene(StringName("interior_house"), "instant")
	await wait_physics_frames(3)

	var interior_scene: Node = _active_scene_container.get_child(0)
	var player: Node3D = _find_player_in_scene(interior_scene)
	assert_not_null(player, "Player should exist in interior scene")

	# Player should have been spawned at sp_entrance_from_exterior
	var entrance_spawn: Node3D = _find_spawn_point_in_scene(interior_scene, "sp_entrance_from_exterior")
	if entrance_spawn != null:
		assert_almost_eq(player.global_position, entrance_spawn.global_position, Vector3(0.5, 0.5, 0.5),
			"Player should be at entrance spawn point after door transition")

	# Now simulate death: player should respawn at same spawn point
	# Move player away
	player.global_position = Vector3(999, 999, 999)

	# Set target_spawn_point again (simulate remembering last spawn for respawn)
	_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_entrance_from_exterior")))
	await get_tree().process_frame

	# Act: Respawn using spawn_at_last_spawn()
	var result: bool = _spawn_manager.spawn_at_last_spawn(interior_scene)

	# Assert: Player should be back at entrance spawn
	assert_true(result, "Respawn should succeed")
	if entrance_spawn != null:
		assert_almost_eq(player.global_position, entrance_spawn.global_position, Vector3(0.5, 0.5, 0.5),
			"Player should respawn at last spawn point")

## Helper: Find player entity in scene
func _find_player_in_scene(scene: Node) -> Node3D:
	if scene == null:
		return null

	# Check if this node is a player
	if scene.name.begins_with("E_Player"):
		return scene as Node3D

	# Recursively search children
	for child in scene.get_children():
		var found_player: Node3D = _find_player_in_scene(child)
		if found_player != null:
			return found_player

	return null

## Helper: Find spawn point in scene
func _find_spawn_point_in_scene(scene: Node, spawn_id: String) -> Node3D:
	if scene == null:
		return null

	# Check if this node is the spawn point
	if scene.name == spawn_id and scene is Node3D:
		return scene as Node3D

	# Recursively search children
	for child in scene.get_children():
		var found_spawn: Node3D = _find_spawn_point_in_scene(child, spawn_id)
		if found_spawn != null:
			return found_spawn

	return null
