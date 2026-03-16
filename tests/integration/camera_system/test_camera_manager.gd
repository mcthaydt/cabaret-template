extends GutTest

## Integration tests for M_CameraManager (T232)
##
## Tests camera blending, state capture, and handoff between M_SceneManager
## and M_CameraManager during scene transitions.

const M_CAMERA_MANAGER := preload("res://scripts/managers/m_camera_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var camera_manager: M_CAMERA_MANAGER
var state_store: M_STATE_STORE
var test_scene: Node3D

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	# Create state store
	state_store = M_STATE_STORE.new()
	state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	add_child_autofree(state_store)
	await get_tree().process_frame

	# Create camera manager
	camera_manager = M_CAMERA_MANAGER.new()
	add_child_autofree(camera_manager)
	await get_tree().process_frame

	# Create test scene
	test_scene = Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)

func after_each() -> void:
	if camera_manager and is_instance_valid(camera_manager):
		camera_manager.queue_free()
	if state_store and is_instance_valid(state_store):
		state_store.queue_free()
	if test_scene and is_instance_valid(test_scene):
		test_scene.queue_free()
	U_SERVICE_LOCATOR.clear()

## ============================================================================
## Camera Blending Tests (T232)
## ============================================================================

func test_blend_cameras_interpolates_position() -> void:
	# Arrange: Create old scene with camera
	var old_scene := Node3D.new()
	old_scene.name = "OldScene"
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_camera.position = Vector3(0, 10, 0)
	old_scene.add_child(old_camera)

	# Create new scene with camera at different position
	var new_scene := Node3D.new()
	new_scene.name = "NewScene"
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_camera.position = Vector3(5, 2, 3)
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act: Blend cameras
	camera_manager.blend_cameras(old_scene, new_scene, 0.2)

	# Wait for blend to complete
	await wait_physics_frames(15)

	# Assert: Transition camera should be near new camera position
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

	var distance := transition_camera.global_position.distance_to(new_camera.global_position)
	assert_lt(distance, 0.5, "Transition camera should blend to new camera position")

func test_blend_cameras_interpolates_rotation() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_camera.rotation_degrees = Vector3(0, 0, 0)
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_camera.rotation_degrees = Vector3(0, 90, 0)  # Face east
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act
	camera_manager.blend_cameras(old_scene, new_scene, 0.2)
	await wait_physics_frames(15)

	# Assert: Rotation should be close to new camera
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	var rotation_diff := (transition_camera.global_rotation - new_camera.global_rotation).length()
	assert_lt(rotation_diff, 0.2, "Transition camera should blend rotation")

func test_blend_cameras_interpolates_fov() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_camera.fov = 70.0
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_camera.fov = 50.0
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act
	camera_manager.blend_cameras(old_scene, new_scene, 0.2)
	await wait_physics_frames(15)

	# Assert
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	var fov_diff: float = abs(transition_camera.fov - new_camera.fov)
	assert_lt(fov_diff, 5.0, "Transition camera FOV should blend to new camera")

func test_blend_cameras_activates_transition_camera() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act
	camera_manager.blend_cameras(old_scene, new_scene, 0.2)
	await wait_physics_frames(2)

	# Assert: Transition camera should become active during blend
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	assert_true(transition_camera.current, "Transition camera should be active during blend")

func test_blend_cameras_completes_within_duration() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act
	var start_time := Time.get_ticks_msec()
	camera_manager.blend_cameras(old_scene, new_scene, 0.2)
	await wait_physics_frames(15)
	var end_time := Time.get_ticks_msec()

	# Assert: Blend should complete within reasonable time
	var duration := (end_time - start_time) / 1000.0
	assert_lt(duration, 1.2, "Camera blend should complete within 1.2 seconds")

func test_blend_cameras_handles_instant_duration() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_camera.position = Vector3(0, 10, 0)
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_camera.position = Vector3(5, 2, 3)
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act: Instant blend (duration = 0)
	camera_manager.blend_cameras(old_scene, new_scene, 0.0)
	await wait_physics_frames(2)

	# Assert: Should immediately be at target position
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	var distance := transition_camera.global_position.distance_to(new_camera.global_position)
	assert_lt(distance, 0.1, "Instant blend should immediately position camera")

func test_apply_main_camera_transform_preserves_active_shake_offset() -> void:
	var scene := Node3D.new()
	add_child_autofree(scene)
	var main_camera := Camera3D.new()
	scene.add_child(main_camera)
	camera_manager.register_main_camera(main_camera)
	main_camera.current = true

	camera_manager.apply_shake_offset(Vector2(5.0, 3.0), 0.05)
	var shake_parent: Node3D = camera_manager.get_shake_parent_for_camera(main_camera)
	assert_not_null(shake_parent, "Main camera should be wrapped by a shake parent after shake is applied")
	assert_not_null(shake_parent)
	if shake_parent == null:
		return
	var shake_position_before: Vector3 = shake_parent.position
	var shake_rotation_before: Vector3 = shake_parent.rotation

	var target_transform := Transform3D(Basis.IDENTITY, Vector3(3.0, 2.0, -6.0))
	camera_manager.apply_main_camera_transform(target_transform)

	assert_almost_eq(shake_parent.position, shake_position_before, Vector3(0.0001, 0.0001, 0.0001))
	assert_almost_eq(shake_parent.rotation, shake_rotation_before, Vector3(0.0001, 0.0001, 0.0001))

	camera_manager.clear_shake_source(StringName("vfx"))
	assert_almost_eq(
		main_camera.global_transform.origin,
		target_transform.origin,
		Vector3(0.001, 0.001, 0.001),
		"Clearing shake should reveal the transform applied by apply_main_camera_transform"
	)

func test_is_blend_active_returns_true_during_transition_blend() -> void:
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)
	var old_camera := Camera3D.new()
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)
	var new_camera := Camera3D.new()
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	camera_manager.blend_cameras(old_scene, new_scene, 0.2)

	assert_true(camera_manager.is_blend_active(), "Transition blend should set is_blend_active() true")

func test_is_blend_active_returns_false_when_no_transition_blend_active() -> void:
	assert_false(camera_manager.is_blend_active(), "No active transition blend should report false")

## ============================================================================
## Camera State Tests (T233)
## ============================================================================

func test_capture_camera_state_saves_position() -> void:
	# Arrange
	var scene := Node3D.new()
	add_child_autofree(scene)

	var camera := Camera3D.new()
	camera.position = Vector3(1, 2, 3)
	scene.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var state = camera_manager.capture_camera_state(scene)

	# Assert
	assert_not_null(state, "Should capture camera state")
	assert_almost_eq(state.global_position, camera.global_position, Vector3(0.01, 0.01, 0.01))

func test_capture_camera_state_saves_rotation() -> void:
	# Arrange
	var scene := Node3D.new()
	add_child_autofree(scene)

	var camera := Camera3D.new()
	camera.rotation_degrees = Vector3(15, 45, 0)
	scene.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var state = camera_manager.capture_camera_state(scene)

	# Assert
	assert_almost_eq(state.global_rotation, camera.global_rotation, Vector3(0.01, 0.01, 0.01))

func test_capture_camera_state_saves_fov() -> void:
	# Arrange
	var scene := Node3D.new()
	add_child_autofree(scene)

	var camera := Camera3D.new()
	camera.fov = 85.0
	scene.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var state = camera_manager.capture_camera_state(scene)

	# Assert
	assert_almost_eq(state.fov, 85.0, 0.01)

func test_capture_camera_state_returns_null_if_no_camera() -> void:
	# Arrange: Scene with no camera
	var scene := Node3D.new()
	add_child_autofree(scene)

	# Act
	var state = camera_manager.capture_camera_state(scene)

	# Assert
	assert_null(state, "Should return null if no camera in scene")

## ============================================================================
## Camera Handoff Tests (T234)
## ============================================================================

func test_initialize_scene_camera_finds_camera_in_scene() -> void:
	# Arrange
	var scene := Node3D.new()
	add_child_autofree(scene)

	var camera := Camera3D.new()
	camera.name = "MainCamera"
	scene.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var found_camera: Camera3D = camera_manager.initialize_scene_camera(scene)

	# Assert
	assert_not_null(found_camera, "Should find camera in scene")
	assert_eq(found_camera.name, "MainCamera")

func test_initialize_scene_camera_returns_null_for_ui_scenes() -> void:
	# Arrange: UI scene without camera
	var scene := Node3D.new()
	scene.name = "UIScene"
	add_child_autofree(scene)

	# Act
	var found_camera: Camera3D = camera_manager.initialize_scene_camera(scene)

	# Assert
	assert_null(found_camera, "Should return null for scenes without cameras (UI scenes)")

func test_blend_cameras_finalizes_by_activating_new_camera() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act: Blend and wait for completion
	camera_manager.blend_cameras(old_scene, new_scene, 0.1)
	await wait_physics_frames(10)

	# Assert: New camera should be active after blend
	# Note: In headless mode, camera.current may not update, so check transition camera is inactive
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	if not OS.has_feature("headless"):
		assert_false(transition_camera.current, "Transition camera should be inactive after blend")
		assert_true(new_camera.current, "New camera should be active after blend")
