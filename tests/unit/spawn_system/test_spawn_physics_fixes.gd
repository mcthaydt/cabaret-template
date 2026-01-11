extends GutTest

## Unit tests for spawn physics fixes to prevent character bobble (T-SpawnBobble)
##
## Tests the three fixes for character bobble on spawn:
## 1. Velocity zeroing when positioning player at spawn point
## 2. Physics warmup frame after unfreezing physics
## 3. Floating component stable state reset on spawn

const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const U_SCENE_LOADER := preload("res://scripts/scene_management/helpers/u_scene_loader.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const RS_FLOATING_SETTINGS := preload("res://scripts/ecs/resources/rs_floating_settings.gd")

var spawn_manager: M_SPAWN_MANAGER
var state_store: M_STATE_STORE
var scene_loader: U_SCENE_LOADER
var test_scene: Node3D

func before_each() -> void:
	# Create state store
	state_store = M_STATE_STORE.new()
	state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	add_child_autofree(state_store)
	U_ServiceLocator.register(StringName("state_store"), state_store)
	await get_tree().process_frame

	# Create spawn manager
	spawn_manager = M_SPAWN_MANAGER.new()
	add_child_autofree(spawn_manager)
	await get_tree().process_frame

	# Create scene loader for unfreeze tests
	scene_loader = U_SCENE_LOADER.new()

	# Create test scene
	test_scene = Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)

func after_each() -> void:
	U_ServiceLocator.clear()

	if spawn_manager and is_instance_valid(spawn_manager):
		spawn_manager.queue_free()
	if state_store and is_instance_valid(state_store):
		state_store.queue_free()
	if test_scene and is_instance_valid(test_scene):
		test_scene.queue_free()

## ============================================================================
## FIX 1: Velocity Zeroing Tests
## ============================================================================

func test_spawn_zeros_player_velocity_on_character_body() -> void:
	# Arrange: Player with residual velocity from previous scene
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	spawn_point.position = Vector3(10, 0, 0)
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.velocity = Vector3(50, 20, -30)  # Residual velocity
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_true(result, "Spawn should succeed")
	assert_eq(player.velocity, Vector3.ZERO, "Player velocity should be zeroed on spawn")

func test_spawn_zeros_velocity_before_freezing_physics() -> void:
	# Arrange: Player with velocity
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.velocity = Vector3(100, 50, 0)
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert: Even though physics is frozen, velocity should already be zero
	assert_eq(player.velocity, Vector3.ZERO, "Velocity should be zero even when physics frozen")
	assert_true(player.has_meta("_spawn_physics_frozen"), "Physics should be frozen")

func test_spawn_velocity_zero_with_high_velocity_values() -> void:
	# Arrange: Extreme velocity values
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.velocity = Vector3(9999, -9999, 5000)  # Extreme velocity
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert
	assert_eq(player.velocity, Vector3.ZERO, "Even extreme velocity should be zeroed")

func test_spawn_handles_non_character_body_player() -> void:
	# Arrange: Player is Node3D, not CharacterBody3D (no velocity property)
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	spawn_point.position = Vector3(5, 0, 0)
	test_scene.add_child(spawn_point)

	var player := Node3D.new()
	player.name = "E_Player"
	test_scene.add_child(player)

	# Act: Should not crash when player has no velocity
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert: Should still position correctly
	assert_true(result, "Spawn should succeed for Node3D player")
	assert_almost_eq(player.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01))

## ============================================================================
## FIX 2: Physics Warmup Frame Tests
## ============================================================================

func test_unfreeze_player_physics_enables_physics_process() -> void:
	# Arrange: Player with frozen physics (simulating post-spawn state)
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.set_physics_process(false)
	player.set_meta("_spawn_physics_frozen", true)
	test_scene.add_child(player)

	# Act
	scene_loader.unfreeze_player_physics(test_scene)

	# Assert
	assert_true(player.is_physics_processing(), "Physics processing should be enabled")
	assert_false(player.has_meta("_spawn_physics_frozen"), "Frozen metadata should be removed")

func test_unfreeze_does_nothing_without_frozen_meta() -> void:
	# Arrange: Player without frozen metadata (normal state)
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.set_physics_process(false)  # Disabled but no frozen meta
	test_scene.add_child(player)

	# Act
	scene_loader.unfreeze_player_physics(test_scene)

	# Assert: Should not enable physics without the meta flag
	assert_false(player.is_physics_processing(), "Physics should remain disabled without frozen meta")

func test_spawn_freezes_physics_for_later_warmup() -> void:
	# Arrange
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.set_physics_process(true)  # Initially enabled
	test_scene.add_child(player)

	# Act
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert: Physics should be frozen, awaiting warmup
	assert_false(player.is_physics_processing(), "Physics should be frozen after spawn")
	assert_true(player.has_meta("_spawn_physics_frozen"), "Should have frozen meta for warmup")

## ============================================================================
## FIX 3: Floating Component Reset Tests
## ============================================================================

func test_floating_component_reset_clears_stable_ground_state() -> void:
	# Arrange: Floating component with accumulated ground state
	var floating := C_FLOATING_COMPONENT.new()
	floating.settings = RS_FLOATING_SETTINGS.new()
	floating.grounded_stable = true
	floating._consecutive_grounded_frames = 15
	floating._consecutive_airborne_frames = 0

	# Simulate: Reset like on spawn
	floating.grounded_stable = false
	floating._consecutive_grounded_frames = 0
	floating._consecutive_airborne_frames = 0

	# Assert
	assert_false(floating.grounded_stable, "Grounded stable should be false after reset")
	assert_eq(floating._consecutive_grounded_frames, 0, "Consecutive grounded frames should be zero")
	assert_eq(floating._consecutive_airborne_frames, 0, "Consecutive airborne frames should be zero")
	floating.free()

func test_floating_component_reset_recent_support_clears_state() -> void:
	# Arrange: Floating component with recent support
	var floating := C_FLOATING_COMPONENT.new()
	floating.settings = RS_FLOATING_SETTINGS.new()
	floating.is_supported = true
	floating._last_support_time = 10.0
	floating.grounded_stable = true
	floating._consecutive_grounded_frames = 20

	var current_time: float = 10.5
	var grace_time: float = 0.1

	# Act: Use existing reset method
	floating.reset_recent_support(current_time, grace_time)

	# Assert
	assert_false(floating.is_supported, "is_supported should be false after reset")
	assert_false(floating.grounded_stable, "grounded_stable should be false after reset")
	assert_eq(floating._consecutive_grounded_frames, 0, "Consecutive grounded should be zero")
	assert_eq(floating._consecutive_airborne_frames, 0, "Consecutive airborne should be zero")
	# _last_support_time should be set to expire grace period
	assert_true(floating._last_support_time < current_time - grace_time, "Support time should be expired")
	floating.free()

func test_floating_component_update_stable_requires_frames() -> void:
	# Arrange: Fresh floating component
	var floating := C_FLOATING_COMPONENT.new()
	floating.settings = RS_FLOATING_SETTINGS.new()
	floating.grounded_stable = false
	floating._consecutive_grounded_frames = 0

	var frames_required: int = 5

	# Act: Simulate grounded frames, not enough to transition
	for i in range(4):
		floating.update_stable_ground_state(true, frames_required)

	# Assert: Not yet stable
	assert_false(floating.grounded_stable, "Should not be stable before required frames")
	assert_eq(floating._consecutive_grounded_frames, 4, "Should have 4 consecutive grounded frames")

	# Act: One more frame
	floating.update_stable_ground_state(true, frames_required)

	# Assert: Now stable
	assert_true(floating.grounded_stable, "Should be stable after required frames")
	floating.free()

func test_floating_component_airborne_resets_grounded_counter() -> void:
	# Arrange
	var floating := C_FLOATING_COMPONENT.new()
	floating.settings = RS_FLOATING_SETTINGS.new()
	floating._consecutive_grounded_frames = 10

	# Act: Single airborne frame
	floating.update_stable_ground_state(false, 5)

	# Assert
	assert_eq(floating._consecutive_grounded_frames, 0, "Grounded counter should reset on airborne")
	assert_eq(floating._consecutive_airborne_frames, 1, "Airborne counter should increment")
	floating.free()

## ============================================================================
## Integration: Full Spawn Flow Tests
## ============================================================================

func test_spawn_full_flow_zeros_velocity_and_freezes_physics() -> void:
	# Arrange: Complete spawn scenario
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	spawn_point.position = Vector3(10, 5, 8)
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.velocity = Vector3(100, 50, -25)
	player.position = Vector3.ZERO
	test_scene.add_child(player)

	# Act
	var result: bool = spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert: All spawn physics fixes applied
	assert_true(result, "Spawn should succeed")
	assert_almost_eq(player.global_position, spawn_point.global_position, Vector3(0.01, 0.01, 0.01), "Position should match spawn point")
	assert_eq(player.velocity, Vector3.ZERO, "Velocity should be zeroed")
	assert_false(player.is_physics_processing(), "Physics should be frozen")
	assert_true(player.has_meta("_spawn_physics_frozen"), "Should have frozen meta")

func test_unfreeze_after_spawn_enables_clean_physics_state() -> void:
	# Arrange: Spawn then unfreeze
	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	test_scene.add_child(spawn_point)

	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.velocity = Vector3(999, 999, 999)
	test_scene.add_child(player)

	# Act: Spawn (freezes physics, zeros velocity)
	spawn_manager.spawn_player_at_point(test_scene, StringName("sp_test"))

	# Assert pre-unfreeze state
	assert_eq(player.velocity, Vector3.ZERO, "Velocity should be zero before unfreeze")
	assert_false(player.is_physics_processing(), "Physics should be frozen before unfreeze")

	# Act: Unfreeze
	scene_loader.unfreeze_player_physics(test_scene)

	# Assert post-unfreeze state
	assert_true(player.is_physics_processing(), "Physics should be enabled after unfreeze")
	assert_false(player.has_meta("_spawn_physics_frozen"), "Frozen meta should be removed")
	assert_eq(player.velocity, Vector3.ZERO, "Velocity should still be zero after unfreeze")
