extends GutTest

## Unit tests for camera state capture and validation (T233-T234)
##
## Tests edge cases for CameraState creation, validation, and camera discovery.

const M_CAMERA_MANAGER := preload("res://scripts/managers/m_camera_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var camera_manager: M_CAMERA_MANAGER
var test_scene: Node3D

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	camera_manager = M_CAMERA_MANAGER.new()
	add_child_autofree(camera_manager)
	await get_tree().process_frame

	test_scene = Node3D.new()
	test_scene.name = "TestScene"
	add_child_autofree(test_scene)

func after_each() -> void:
	if camera_manager and is_instance_valid(camera_manager):
		camera_manager.queue_free()
	if test_scene and is_instance_valid(test_scene):
		test_scene.queue_free()
	U_SERVICE_LOCATOR.clear()

## ============================================================================
## CameraState Creation Tests
## ============================================================================

func test_camera_state_stores_all_properties() -> void:
	# Arrange
	var camera := Camera3D.new()
	camera.position = Vector3(1, 2, 3)
	camera.rotation_degrees = Vector3(10, 20, 30)
	camera.fov = 60.0
	test_scene.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var state = camera_manager.capture_camera_state(test_scene)

	# Assert
	assert_not_null(state)
	assert_almost_eq(state.global_position.x, 1.0, 0.01)
	assert_almost_eq(state.global_position.y, 2.0, 0.01)
	assert_almost_eq(state.global_position.z, 3.0, 0.01)
	assert_almost_eq(state.fov, 60.0, 0.01)

func test_camera_state_uses_global_transforms() -> void:
	# Arrange: Nested camera with local transform
	var container := Node3D.new()
	container.position = Vector3(10, 0, 0)
	test_scene.add_child(container)

	var camera := Camera3D.new()
	camera.position = Vector3(5, 0, 0)  # Local position
	container.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var state = camera_manager.capture_camera_state(test_scene)

	# Assert: Should use global position (10 + 5 = 15)
	assert_almost_eq(state.global_position.x, 15.0, 0.01)

## ============================================================================
## Camera Discovery Edge Cases
## ============================================================================

func test_capture_handles_multiple_cameras_uses_first() -> void:
	# Arrange: Multiple cameras with first registered
	var camera1 := Camera3D.new()
	camera1.name = "Camera1"
	camera1.position = Vector3(1, 0, 0)
	test_scene.add_child(camera1)
	camera_manager.register_main_camera(camera1)

	var camera2 := Camera3D.new()
	camera2.name = "Camera2"
	camera2.position = Vector3(10, 0, 0)
	test_scene.add_child(camera2)

	# Act
	var state = camera_manager.capture_camera_state(test_scene)

	# Assert: Should use first camera found
	assert_not_null(state)
	# Position should be from one of the cameras
	var dist_to_cam1: float = state.global_position.distance_to(camera1.global_position)
	var uses_first: bool = dist_to_cam1 < 0.1
	assert_true(uses_first, "Should use first camera when multiple found")

func test_capture_returns_null_for_empty_scene() -> void:
	# Arrange: Empty scene
	var empty_scene := Node3D.new()
	add_child_autofree(empty_scene)

	# Act
	var state = camera_manager.capture_camera_state(empty_scene)

	# Assert
	assert_null(state, "Should return null for scene without camera")

func test_capture_handles_camera_not_in_group_when_registered() -> void:
	# Arrange: Camera exists but not in "main_camera" group
	var camera := Camera3D.new()
	camera.name = "SomeCamera"
	test_scene.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var state = camera_manager.capture_camera_state(test_scene)

	# Assert
	assert_not_null(state, "Should find camera even if it is not in the main_camera group")
	assert_eq(state.global_position, camera.global_position)

## ============================================================================
## Camera Initialization Tests
## ============================================================================

func test_initialize_scene_camera_finds_deeply_nested_camera() -> void:
	# Arrange: Camera deep in hierarchy
	var level1 := Node3D.new()
	test_scene.add_child(level1)

	var level2 := Node3D.new()
	level1.add_child(level2)

	var camera := Camera3D.new()
	level2.add_child(camera)
	camera_manager.register_main_camera(camera)

	# Act
	var found_camera := camera_manager.initialize_scene_camera(test_scene)

	# Assert
	assert_not_null(found_camera, "Should find deeply nested camera")
	assert_eq(found_camera, camera)

func test_initialize_scene_camera_handles_null_scene() -> void:
	# Act
	var found_camera := camera_manager.initialize_scene_camera(null)

	# Assert
	assert_null(found_camera, "Should handle null scene gracefully")

## ============================================================================
## Transition Camera Tests
## ============================================================================

func test_transition_camera_exists_after_blend() -> void:
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
	camera_manager.blend_cameras(old_scene, new_scene, 0.1)

	# Assert
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	assert_not_null(transition_camera, "Transition camera should exist")

func test_transition_camera_positioned_at_old_camera() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_camera.position = Vector3(5, 10, 15)
	old_camera.rotation_degrees = Vector3(0, 45, 0)
	old_camera.fov = 75.0
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act
	camera_manager.blend_cameras(old_scene, new_scene, 0.2)
	await get_tree().process_frame  # Wait for transform updates

	# Assert: Transition camera should start at old camera position
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	var pos_diff := transition_camera.global_position.distance_to(old_camera.global_position)
	assert_lt(pos_diff, 0.5, "Transition camera should start near old camera position (blend may have started)")

## ============================================================================
## Blend Duration Tests
## ============================================================================

func test_zero_duration_blend_completes_instantly() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_camera.position = Vector3(0, 0, 0)
	old_scene.add_child(old_camera)

	var new_scene := Node3D.new()
	add_child_autofree(new_scene)

	var new_camera := Camera3D.new()
	new_camera.position = Vector3(100, 100, 100)
	new_scene.add_child(new_camera)
	camera_manager.register_main_camera(new_camera)

	# Act: Instant blend
	camera_manager.blend_cameras(old_scene, new_scene, 0.0)
	await wait_physics_frames(1)

	# Assert: Should be at target immediately
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	var distance := transition_camera.global_position.distance_to(new_camera.global_position)
	assert_lt(distance, 0.1, "Zero duration blend should complete instantly")

func test_blend_kills_existing_tween_before_starting_new() -> void:
	# Arrange
	var old_scene := Node3D.new()
	add_child_autofree(old_scene)

	var old_camera := Camera3D.new()
	old_scene.add_child(old_camera)

	var new_scene1 := Node3D.new()
	add_child_autofree(new_scene1)

	var new_camera1 := Camera3D.new()
	new_camera1.position = Vector3(10, 0, 0)
	new_scene1.add_child(new_camera1)

	var new_scene2 := Node3D.new()
	add_child_autofree(new_scene2)

	var new_camera2 := Camera3D.new()
	new_camera2.position = Vector3(0, 10, 0)
	new_scene2.add_child(new_camera2)

	# Act: Start first blend, then immediately start second
	camera_manager.register_main_camera(new_camera1)
	camera_manager.blend_cameras(old_scene, new_scene1, 0.5)
	await wait_physics_frames(2)
	camera_manager.register_main_camera(new_camera2)
	camera_manager.blend_cameras(old_scene, new_scene2, 0.5)
	await wait_physics_frames(35)  # Wait for 0.5 second blend to complete (30 frames + buffer)

	# Assert: Should end at second target position
	var transition_camera: Camera3D = camera_manager.get("_transition_camera")
	var distance := transition_camera.global_position.distance_to(new_camera2.global_position)
	assert_lt(distance, 0.5, "Second blend should override first and complete")
