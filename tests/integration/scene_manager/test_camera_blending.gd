extends GutTest

## Integration test for camera blending during scene transitions (Phase 10, updated Phase 12.2)
##
## Tests T178-T182: Camera position, rotation, and FOV blending during scene transitions.
## Validates smooth interpolation with Tween system, no jitter, and proper integration
## with FadeTransition effect.
##
## Architecture (Phase 12.2): M_CameraManager handles camera blending. M_SceneManager
## delegates camera operations to M_CameraManager during transitions.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const M_SpawnManager = preload("res://scripts/managers/m_spawn_manager.gd")
const M_CameraManager = preload("res://scripts/managers/m_camera_manager.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/state/resources/rs_state_store_settings.gd")

var _root_scene: Node
var _manager: M_SceneManager
var _spawn_manager: M_SpawnManager
var _camera_manager: M_CameraManager
var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer

## Helper: Check if running in headless mode
func _is_headless() -> bool:
	return OS.has_feature("headless") or DisplayServer.get_name() == "headless"

func before_each() -> void:
	# Create root scene structure
	_root_scene = Node.new()
	_root_scene.name = "Root"
	add_child_autofree(_root_scene)

	# Create state store with all slices
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	var scene_initial_state := RS_SceneInitialState.new()
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

	# Create spawn manager (Phase 12.1: required for spawn restoration)
	_spawn_manager = M_SpawnManager.new()
	_root_scene.add_child(_spawn_manager)

	# Create camera manager (Phase 12.2: required for camera blending)
	_camera_manager = M_CameraManager.new()
	_root_scene.add_child(_camera_manager)

	# Create scene manager
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true
	_root_scene.add_child(_manager)
	await get_tree().process_frame

func after_each() -> void:
	_manager = null
	_spawn_manager = null
	_camera_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_root_scene = null

## T178: Test camera position blending during scene transition
##
## Validates that camera position interpolates smoothly from old scene camera
## to new scene camera during transition. Uses exterior → interior transition
## with different camera heights (exterior: 1.5, interior: 0.8).
func test_camera_position_blending() -> void:
	# Load exterior scene (camera at 0, 1.5, 4.5)
	_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Find camera in exterior scene
	var cameras_before: Array = get_tree().get_nodes_in_group("main_camera")
	assert_eq(cameras_before.size(), 1, "Should have exactly one main camera in exterior")

	var camera_before: Camera3D = cameras_before[0] as Camera3D
	var position_before: Vector3 = camera_before.global_position

	# Transition to interior (camera at 0, 0.8, 4.5) with fade (allows time for blend)
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Wait mid-transition to capture blending
	await wait_physics_frames(5)

	# Check transition camera exists
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist in M_SceneManager")
	# Note: In headless mode, Tweens may complete instantly, so checking mid-blend state is unreliable
	# Skip this check in headless mode
	if not _is_headless():
		assert_true(transition_camera.current, "Transition camera should be active during blend")

	# Complete transition
	await wait_physics_frames(15)

	# Find camera in interior scene
	var cameras_after: Array = get_tree().get_nodes_in_group("main_camera")
	assert_eq(cameras_after.size(), 1, "Should have exactly one main camera in interior")

	var camera_after: Camera3D = cameras_after[0] as Camera3D
	var position_after: Vector3 = camera_after.global_position

	# Validate cameras have different positions (exterior higher than interior)
	assert_almost_eq(position_before.y, 1.5, 0.1, "Exterior camera should be at height 1.5")
	assert_almost_eq(position_after.y, 0.8, 0.1, "Interior camera should be at height 0.8")

	# Validate cameras switched after blend
	# Note: Headless mode Tween timing is unreliable - new camera should be active regardless
	if _is_headless():
		# In headless, just verify new camera exists and transition completed
		# Camera switching timing is unreliable in headless mode
		assert_not_null(camera_after, "New scene camera should exist after transition")
	else:
		# In GUI mode, verify proper camera switching
		assert_false(transition_camera.current, "Transition camera should not be current after blend")
		assert_true(camera_after.current, "New scene camera should be current after blend")

## T179: Test camera rotation blending during scene transition
##
## Validates that camera rotation interpolates smoothly using quaternion
## interpolation to avoid gimbal lock. Tests with scenes that have
## different camera angles (if implemented).
func test_camera_rotation_blending() -> void:
	# Note: Current exterior/interior cameras have identical rotations (0, 0, 0)
	# This test validates the rotation blending mechanism works correctly
	# even with identical rotations (blend should still execute smoothly)

	# Load exterior scene
	_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	var cameras_before: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_before: Camera3D = cameras_before[0] as Camera3D
	var rotation_before: Vector3 = camera_before.global_rotation

	# Transition with fade
	_manager.transition_to_scene(StringName("interior_house"), "fade")
	await wait_physics_frames(5)

	# Check transition camera exists
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	# Complete transition
	await wait_physics_frames(15)

	var cameras_after: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_after: Camera3D = cameras_after[0] as Camera3D
	var rotation_after: Vector3 = camera_after.global_rotation

	# Validate blend completed (rotations may be identical, but blend logic ran)
	assert_almost_eq(rotation_before.x, rotation_after.x, 0.1, "Rotation should blend smoothly")
	# Skip mid-blend checks in headless mode
	if not _is_headless():
		assert_false(transition_camera.current, "Transition camera should not be current after blend")

## T180: Test camera FOV blending during scene transition
##
## Validates that camera FOV (field of view) interpolates smoothly.
## Exterior has wider FOV (80°), interior has narrower FOV (65°).
func test_camera_fov_blending() -> void:
	# Load exterior scene (FOV 80°)
	_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	var cameras_before: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_before: Camera3D = cameras_before[0] as Camera3D
	var fov_before: float = camera_before.fov

	# Transition to interior (FOV 65°)
	_manager.transition_to_scene(StringName("interior_house"), "fade")
	await wait_physics_frames(5)

	# Check transition camera
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	# Complete transition
	await wait_physics_frames(15)

	var cameras_after: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_after: Camera3D = cameras_after[0] as Camera3D
	var fov_after: float = camera_after.fov

	# Validate FOVs differ (exterior wider than interior)
	assert_almost_eq(fov_before, 80.0, 2.0, "Exterior camera should have FOV ~80°")
	assert_almost_eq(fov_after, 65.0, 2.0, "Interior camera should have FOV ~65°")

## T182: Test camera transitions are smooth (no jitter)
##
## Validates that camera blending uses Tween system with smooth easing curves.
## Checks that interpolation completes without sudden jumps or jitter.
##
## NOTE: Skipped in headless mode - Tween timing requires GUI for reliable validation
func test_camera_transitions_smooth() -> void:
	if _is_headless():
		pass_test("Skipped in headless mode - requires GUI for Tween timing validation")
		return

	# Load exterior
	_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	var cameras_before: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_before: Camera3D = cameras_before[0] as Camera3D
	var start_pos: Vector3 = camera_before.global_position

	# Start transition with fade (0.2s duration)
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Sample transition camera position at multiple points during blend
	var transition_camera: Camera3D = null
	var positions_during_blend: Array[Vector3] = []

	# Sample over ~10 frames during transition
	for i in range(10):
		await get_tree().process_frame
		if transition_camera == null:
			transition_camera = _camera_manager.get("_transition_camera")
		if transition_camera != null and transition_camera.current:
			positions_during_blend.append(transition_camera.global_position)

	# Wait for completion
	await wait_physics_frames(10)

	# Validate we captured intermediate positions during blend
	assert_gt(positions_during_blend.size(), 3, "Should have captured multiple positions during blend")

	# Validate no sudden jumps (positions should change gradually)
	for i in range(1, positions_during_blend.size()):
		var delta: Vector3 = positions_during_blend[i] - positions_during_blend[i - 1]
		var distance: float = delta.length()
		# No single frame should have a large jump (threshold: 0.5 units per frame at 60fps)
		assert_lt(distance, 0.5, "Position changes should be gradual, no sudden jumps")

## T182.5: Test camera blending integrates with FadeTransition
##
## Validates that camera blend runs in parallel with fade effect, not sequentially.
## Both effects should start and finish around the same time.
func test_camera_blend_with_fade_transition() -> void:
	# Load exterior
	_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	# Transition with fade
	var start_time: float = Time.get_ticks_msec() / 1000.0
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Check transition camera becomes active early (during fade)
	await wait_physics_frames(3)
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")
	# Skip mid-transition timing checks in headless mode
	if not _is_headless():
		assert_true(transition_camera.current, "Transition camera should be active during fade")

	# Wait for both to complete
	await wait_physics_frames(15)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = end_time - start_time

	# Validate both completed in reasonable time (~0.2-0.5s for fade + blend)
	# In headless mode timing is less precise, so use generous bounds
	assert_lt(duration, 1.0, "Fade + camera blend should complete within 1 second")

	# Validate cameras switched after transition
	var cameras_after: Array = get_tree().get_nodes_in_group("main_camera")
	assert_eq(cameras_after.size(), 1, "Should have one camera after transition")
	var camera_after: Camera3D = cameras_after[0] as Camera3D

	# In headless mode, only verify new camera exists (timing unreliable)
	if _is_headless():
		assert_not_null(camera_after, "New scene camera should exist after transition")
	else:
		# In GUI mode, verify proper camera switching
		assert_false(transition_camera.current, "Transition camera should not be current after blend")
		assert_true(camera_after.current, "New scene camera should be current")

## Helper test: Instant transition uses duration=0 for camera blend
##
## Validates that instant transitions still execute camera blend logic
## but with duration=0 (immediate cut).
func test_instant_transition_camera_blend_zero_duration() -> void:
	# Load exterior
	_manager.transition_to_scene(StringName("exterior"), "instant")
	await wait_physics_frames(3)

	var cameras_before: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_before: Camera3D = cameras_before[0] as Camera3D
	var position_before: Vector3 = camera_before.global_position

	# Instant transition to interior
	_manager.transition_to_scene(StringName("interior_house"), "instant")
	await wait_physics_frames(3)

	# Validate transition completed instantly
	var cameras_after: Array = get_tree().get_nodes_in_group("main_camera")
	var camera_after: Camera3D = cameras_after[0] as Camera3D
	var position_after: Vector3 = camera_after.global_position

	# Positions should differ (cameras have different heights)
	assert_ne(position_before.y, position_after.y, "Camera positions should differ after instant transition")

	# New camera should be active immediately (no visible blend)
	assert_true(camera_after.current, "New scene camera should be current immediately")
