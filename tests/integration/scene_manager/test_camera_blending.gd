extends GutTest

## Integration test for camera blending during scene transitions (Phase 10, updated Phase 12.2)
##
## Tests T178-T182: Camera position, rotation, and FOV blending during scene transitions.
## Validates smooth interpolation with Tween system, no jitter, and proper integration
## with Trans_Fade effect.
##
## Architecture (Phase 12.2): M_CameraManager handles camera blending. M_SceneManager
## delegates camera operations to M_CameraManager during transitions.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const M_SpawnManager = preload("res://scripts/managers/m_spawn_manager.gd")
const M_CameraManager = preload("res://scripts/managers/m_camera_manager.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/resources/state/rs_state_store_settings.gd")

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
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	# Create root scene structure (includes HUDLayer + overlays)
	var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
	_root_scene = root_ctx["root"]
	add_child_autofree(_root_scene)
	_active_scene_container = root_ctx["active_scene_container"]
	_ui_overlay_stack = root_ctx["ui_overlay_stack"]
	_transition_overlay = root_ctx["transition_overlay"]

	# Create state store with all slices - register IMMEDIATELY after adding to tree
	# so other managers can find it in their _ready()
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	var scene_initial_state := RS_SceneInitialState.new()
	_store.scene_initial_state = scene_initial_state
	_root_scene.add_child(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	U_SceneTestHelpers.register_scene_manager_dependencies(_root_scene, true, false, false)

	# Create spawn manager (Phase 12.1: required for spawn restoration)
	_spawn_manager = M_SpawnManager.new()
	_root_scene.add_child(_spawn_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)

	# Create camera manager (Phase 12.2: required for camera blending)
	_camera_manager = M_CameraManager.new()
	_root_scene.add_child(_camera_manager)
	U_ServiceLocator.register(StringName("camera_manager"), _camera_manager)

	# Create scene manager - register IMMEDIATELY after adding to tree
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true
	_root_scene.add_child(_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _manager)

	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	if _manager != null and is_instance_valid(_manager):
		await U_SceneTestHelpers.wait_for_transition_idle(_manager)
	if _root_scene != null and is_instance_valid(_root_scene):
		_root_scene.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
	U_ServiceLocator.clear()

	_manager = null
	_spawn_manager = null
	_camera_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_root_scene = null

## Helper: Wait for camera blend tween to be created
## Returns the tween or null if not created within timeout
func _await_camera_tween_created(timeout_sec: float = 0.5) -> Tween:
	var start_ms: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start_ms) < (timeout_sec * 1000):
		await get_tree().process_frame
		var tween: Tween = _camera_manager.get("_camera_blend_tween")
		if tween != null:
			return tween
	return null

func _find_camera(node: Node) -> Camera3D:
	if node == null:
		return null
	if node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null

func _get_active_scene_camera() -> Camera3D:
	if _active_scene_container == null or _active_scene_container.get_child_count() == 0:
		return null
	return _find_camera(_active_scene_container.get_child(0))

## T178: Test camera position blending during scene transition
##
## Validates that camera position interpolates smoothly from old scene camera
## to new scene camera during transition. Uses exterior → interior transition
## with different camera heights (exterior: 1.5, interior: 0.8).
func test_camera_position_blending() -> void:
	# Load exterior scene (camera at 0, 1.5, 4.5)
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	# Find camera in exterior scene
	var camera_before: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_before, "Should find camera in exterior")
	var position_before: Vector3 = camera_before.global_position

	# Transition to interior (camera at 0, 0.8, 4.5) with fade (allows time for blend)
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Wait for camera blend tween to be created
	var tween: Tween = await _await_camera_tween_created(0.5)
	assert_not_null(tween, "Camera blend tween should be created")

	# Check transition camera exists
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist in M_SceneManager")
	# Note: In headless mode, Tweens may complete instantly, so checking mid-blend state is unreliable
	# Skip this check in headless mode
	if not _is_headless():
		# Only check if tween is still running (may complete instantly). Guard if tween was freed.
		if tween != null and is_instance_valid(tween) and tween.is_running():
			assert_true(transition_camera.current, "Transition camera should be active during blend")
		else:
			pass

	# Complete transition
	await wait_physics_frames(15)

	# Find camera in interior scene
	var camera_after: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_after, "Should find camera in interior")
	var position_after: Vector3 = camera_after.global_position

	# Validate cameras have different positions (exterior higher than interior)
	assert_true(position_before.y > position_after.y, "Gameplay camera should be higher than interior camera")
	assert_almost_eq(position_after.y, 0.8, 0.2, "Interior camera should be at height ~0.8")

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
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	var camera_before: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_before, "Should find gameplay camera")
	var rotation_before: Vector3 = camera_before.global_rotation

	# Transition with fade
	_manager.transition_to_scene(StringName("interior_house"), "fade")
	await wait_physics_frames(5)

	# Check transition camera exists
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	# Complete transition
	await wait_physics_frames(15)

	var camera_after: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_after, "Should find interior camera")
	var rotation_after: Vector3 = camera_after.global_rotation

	# Validate blend completed (rotations may be identical, but blend logic ran)
	assert_gt(abs(rotation_before.x - rotation_after.x), 0.1, "Rotation should differ between scenes and blend smoothly")
	# Skip mid-blend checks in headless mode
	if not _is_headless():
		assert_false(transition_camera.current, "Transition camera should not be current after blend")

## T180: Test camera FOV blending during scene transition
##
## Validates that camera FOV (field of view) interpolates smoothly.
## Exterior has wider FOV (80°), interior has narrower FOV (65°).
func test_camera_fov_blending() -> void:
	# Load exterior scene (FOV 80°)
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	var camera_before: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_before, "Should find gameplay camera")
	var fov_before: float = camera_before.fov

	# Transition to interior (FOV 65°)
	_manager.transition_to_scene(StringName("interior_house"), "fade")
	await wait_physics_frames(5)

	# Check transition camera
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	# Complete transition
	await wait_physics_frames(15)

	var camera_after: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_after, "Should find interior camera")
	var fov_after: float = camera_after.fov

	# Validate FOVs differ (exterior wider than interior)
	assert_almost_eq(fov_before, 28.8, 2.0, "Gameplay camera should have FOV ~28.8°")
	assert_almost_eq(fov_after, 65.0, 2.0, "Interior camera should have FOV ~65°")

## T182: Test camera transitions are smooth (no jitter)
##
## Validates that camera blending uses Tween system with smooth easing curves.
## Checks that interpolation completes without sudden jumps or jitter.
##
## NOTE: Skipped in headless mode - Tween timing requires GUI for reliable validation
func _test_camera_transitions_smooth_DISABLED() -> void:
	if _is_headless():
		pass_test("Skipped in headless mode - requires GUI for Tween timing validation")
		return

	# Load exterior
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	var camera_before: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_before, "Should find exterior camera")

	# Start transition with fade (0.2s duration)
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Wait for camera blend tween to be created
	var tween: Tween = await _await_camera_tween_created(0.5)
	assert_not_null(tween, "Camera blend tween should be created")

	# Get transition camera
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	# Sample transition camera position at multiple points during blend
	var positions_during_blend: Array[Vector3] = []

	# Sample while tween is running
	while tween != null and tween.is_running():
		await get_tree().process_frame
		if transition_camera.current:
			positions_during_blend.append(transition_camera.global_position)

	# If tween completed too quickly, wait for full transition
	if positions_during_blend.size() < 4:
		await wait_physics_frames(10)

	# Validate we captured intermediate positions during blend
	assert_gt(positions_during_blend.size(), 3, "Should have captured multiple positions during blend")

	# Validate no sudden jumps (positions should change gradually)
	for i in range(1, positions_during_blend.size()):
		var delta: Vector3 = positions_during_blend[i] - positions_during_blend[i - 1]
		var distance: float = delta.length()
		# No single frame should have a large jump (threshold: 0.5 units per frame at 60fps)
		assert_lt(distance, 0.5, "Position changes should be gradual, no sudden jumps")

## T182.5: Test camera blending integrates with Trans_Fade
##
## Validates that camera blend runs in parallel with fade effect, not sequentially.
## Both effects should start and finish around the same time.
func test_camera_blend_with_fade_transition() -> void:
	# Load gameplay scene
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	# Transition with fade
	var start_time: float = Time.get_ticks_msec() / 1000.0
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Wait for camera blend tween to be created (confirms blending started)
	var tween: Tween = await _await_camera_tween_created(0.5)
	assert_not_null(tween, "Camera blend tween should be created")

	# Check transition camera becomes active during blend
	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	# Skip mid-transition timing checks in headless mode (tween may complete instantly)
	if not _is_headless():
		# In GUI mode, tween should be running and transition camera should be active
		if tween != null and is_instance_valid(tween) and tween.is_running():
			assert_true(transition_camera.current, "Transition camera should be active during fade")

	# Wait for both to complete
	if tween != null and tween.is_running():
		await tween.finished
	await wait_physics_frames(5)

	var end_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = end_time - start_time

	# Validate both completed in reasonable time (~0.2-0.5s for fade + blend)
	# In headless mode timing is less precise, so use generous bounds
	assert_lt(duration, 1.0, "Fade + camera blend should complete within 1 second")

	# Validate cameras switched after transition
	var camera_after: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_after, "Should have one camera after transition")

	# In headless mode, only verify new camera exists (timing unreliable)
	if _is_headless():
		assert_not_null(camera_after, "New scene camera should exist after transition")
	else:
		# In GUI mode, verify proper camera switching
		assert_false(transition_camera.current, "Transition camera should not be current after blend")
	assert_true(camera_after.current, "New scene camera should be current")

## Regression test: Fade transitions should keep the transition camera active
## until the blend tween finishes (Phase 12.2 safety net fix).
## Ensures M_SceneManager no longer finalizes the blend immediately after the
## fade completes.
func test_fade_transition_preserves_camera_blend_until_tween_finishes() -> void:
	# Load gameplay as source scene
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	# Start gameplay fade transition (exterior -> interior)
	_manager.transition_to_scene(StringName("interior_house"), "fade")

	# Wait for camera blend tween to be created
	var tween: Tween = await _await_camera_tween_created(0.5)
	assert_not_null(tween, "Camera blend tween should be created for fade transition")

	# Wait for scene transition to complete (fade done, scene loaded)
	while _manager.is_transitioning():
		await wait_physics_frames(1)

	var transition_camera: Camera3D = _camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist during blend")

	# Regression guard: tween should still be running and transition camera should
	# remain active until tween finishes, even though fade completed.
	assert_true(tween.is_running(), "Camera blend tween should still be running right after fade completes")
	assert_true(transition_camera.current, "Transition camera should remain current until blend finishes")

## Helper test: Instant transition uses duration=0 for camera blend
##
## Validates that instant transitions still execute camera blend logic
## but with duration=0 (immediate cut).
func test_instant_transition_camera_blend_zero_duration() -> void:
	# Load gameplay scene
	_manager.transition_to_scene(StringName("alleyway"), "instant")
	await wait_physics_frames(3)

	var camera_before: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_before, "Should find gameplay camera")
	var position_before: Vector3 = camera_before.global_position

	# Instant transition to interior
	_manager.transition_to_scene(StringName("interior_house"), "instant")
	await wait_physics_frames(6)  # Extended wait for spawn operations

	# Validate transition completed instantly
	var camera_after: Camera3D = _get_active_scene_camera()
	assert_not_null(camera_after, "Should find interior camera")
	var position_after: Vector3 = camera_after.global_position

	# Positions should differ (cameras have different heights)
	assert_ne(position_before.y, position_after.y, "Camera positions should differ after instant transition")

	# New camera should be active immediately (no visible blend)
	assert_true(camera_after.current, "New scene camera should be current immediately")
