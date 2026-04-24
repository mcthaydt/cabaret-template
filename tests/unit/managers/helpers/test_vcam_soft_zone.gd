extends GutTest

const SOFT_ZONE_HELPER := preload("res://scripts/core/managers/helpers/u_vcam_soft_zone.gd")
const SOFT_ZONE_RESOURCE := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")

func _new_soft_zone(
	dead_zone_width: float = 0.1,
	dead_zone_height: float = 0.1,
	soft_zone_width: float = 0.4,
	soft_zone_height: float = 0.4,
	damping: float = 2.0,
	hysteresis_margin: float = 0.02
) -> Resource:
	var soft_zone := SOFT_ZONE_RESOURCE.new()
	soft_zone.dead_zone_width = dead_zone_width
	soft_zone.dead_zone_height = dead_zone_height
	soft_zone.soft_zone_width = soft_zone_width
	soft_zone.soft_zone_height = soft_zone_height
	soft_zone.damping = damping
	soft_zone.hysteresis_margin = hysteresis_margin
	return soft_zone

func _create_projection_camera(viewport_size: Vector2i = Vector2i(1000, 1000)) -> Camera3D:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = false
	viewport.own_world_3d = true
	add_child_autofree(viewport)

	var camera := Camera3D.new()
	camera.fov = 75.0
	viewport.add_child(camera)
	autofree(camera)
	camera.current = true
	return camera

func _world_from_normalized(
	camera: Camera3D,
	desired_transform: Transform3D,
	normalized_screen_pos: Vector2,
	depth: float
) -> Vector3:
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var previous_transform: Transform3D = camera.global_transform
	camera.global_transform = desired_transform
	var screen_point := Vector2(
		normalized_screen_pos.x * viewport_size.x,
		normalized_screen_pos.y * viewport_size.y
	)
	var world_point: Vector3 = camera.project_position(screen_point, depth)
	camera.global_transform = previous_transform
	return world_point

func _normalized_from_world(
	camera: Camera3D,
	camera_transform: Transform3D,
	world_pos: Vector3
) -> Vector2:
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var previous_transform: Transform3D = camera.global_transform
	camera.global_transform = camera_transform
	var screen_point: Vector2 = camera.unproject_position(world_pos)
	camera.global_transform = previous_transform
	return Vector2(screen_point.x / viewport_size.x, screen_point.y / viewport_size.y)

func test_target_inside_dead_zone_returns_zero_correction() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.52, 0.5), 10.0)
	var soft_zone: Resource = _new_soft_zone()

	var correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016
	)

	assert_true(correction.length() <= 0.0001)

func test_target_in_soft_zone_returns_damped_non_zero_correction() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.62, 0.5), 10.0)
	var soft_zone: Resource = _new_soft_zone()

	var correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016
	)
	var corrected_transform := desired_transform
	corrected_transform.origin += correction
	var normalized_after: Vector2 = _normalized_from_world(camera, corrected_transform, follow_world_pos)

	assert_true(correction.length() > 0.0001)
	assert_true(normalized_after.x < 0.62)
	assert_true(normalized_after.x > 0.55)

func test_target_outside_soft_zone_is_clamped_to_soft_boundary() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.92, 0.5), 10.0)
	var soft_zone: Resource = _new_soft_zone()

	var correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016
	)
	var corrected_transform := desired_transform
	corrected_transform.origin += correction
	var normalized_after: Vector2 = _normalized_from_world(camera, corrected_transform, follow_world_pos)

	assert_true(correction.length() > 0.0001)
	assert_almost_eq(normalized_after.x, 0.7, 0.001)

func test_correction_magnitude_scales_with_damping() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.62, 0.5), 10.0)
	var low_damping_zone: Resource = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 1.0)
	var high_damping_zone: Resource = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 8.0)

	var low_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		low_damping_zone,
		0.016
	)
	var high_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		high_damping_zone,
		0.016
	)

	assert_true(high_correction.length() > low_correction.length())

func test_soft_zone_null_returns_zero_correction() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.62, 0.5), 10.0)

	var correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		null,
		0.016
	)

	assert_true(correction.length() <= 0.0001)

func test_correction_behaves_consistently_across_viewport_sizes() -> void:
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone()

	var small_camera: Camera3D = _create_projection_camera(Vector2i(640, 360))
	var small_follow: Vector3 = _world_from_normalized(small_camera, desired_transform, Vector2(0.62, 0.5), 10.0)
	var small_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		small_camera,
		small_follow,
		desired_transform,
		soft_zone,
		0.016
	)
	var small_transform := desired_transform
	small_transform.origin += small_correction
	var small_after: Vector2 = _normalized_from_world(small_camera, small_transform, small_follow)

	var large_camera: Camera3D = _create_projection_camera(Vector2i(1920, 1080))
	var large_follow: Vector3 = _world_from_normalized(large_camera, desired_transform, Vector2(0.62, 0.5), 10.0)
	var large_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		large_camera,
		large_follow,
		desired_transform,
		soft_zone,
		0.016
	)
	var large_transform := desired_transform
	large_transform.origin += large_correction
	var large_after: Vector2 = _normalized_from_world(large_camera, large_transform, large_follow)

	assert_true(small_correction.length() > 0.0001)
	assert_true(large_correction.length() > 0.0001)
	assert_almost_eq(small_after.x, large_after.x, 0.001)

func test_correction_works_for_near_and_far_depths() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone()

	var near_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.62, 0.5), 5.0)
	var far_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.62, 0.5), 30.0)

	var near_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		near_follow,
		desired_transform,
		soft_zone,
		0.016
	)
	var far_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		far_follow,
		desired_transform,
		soft_zone,
		0.016
	)

	assert_true(near_correction.length() > 0.0001)
	assert_true(far_correction.length() > 0.0001)
	assert_true(far_correction.length() > near_correction.length())

func test_correction_direction_moves_toward_nearest_allowed_boundary() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone()

	var right_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.62, 0.5), 10.0)
	var left_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.38, 0.5), 10.0)

	var right_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		right_follow,
		desired_transform,
		soft_zone,
		0.016
	)
	var left_correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		left_follow,
		desired_transform,
		soft_zone,
		0.016
	)

	assert_true(right_correction.x > 0.0)
	assert_true(left_correction.x < 0.0)

func test_zero_dead_zone_triggers_correction_for_any_offset() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.51, 0.5), 10.0)
	var soft_zone: Resource = _new_soft_zone(0.0, 0.0, 0.4, 0.4, 20.0)

	var correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016
	)

	assert_true(correction.length() > 0.0001)

func test_full_viewport_soft_zone_avoids_hard_clamp() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.92, 0.5), 10.0)
	var soft_zone: Resource = _new_soft_zone(0.1, 0.1, 1.0, 1.0, 2.0)

	var correction: Vector3 = SOFT_ZONE_HELPER.compute_camera_correction(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016
	)
	var corrected_transform := desired_transform
	corrected_transform.origin += correction
	var normalized_after: Vector2 = _normalized_from_world(camera, corrected_transform, follow_world_pos)

	assert_true(normalized_after.x < 0.92)
	assert_true(normalized_after.x > 0.8)

func test_hysteresis_exit_threshold_uses_dead_zone_plus_margin() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 20.0, 0.02)
	var state: Dictionary = {"x": true, "y": true}

	var inside_exit_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.565, 0.5), 10.0)
	var inside_exit_result: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
		camera,
		inside_exit_follow,
		desired_transform,
		soft_zone,
		0.016,
		state
	)
	var inside_exit_state: Dictionary = inside_exit_result.get("dead_zone_state", {})
	assert_true(bool(inside_exit_state.get("x", false)))
	assert_true((inside_exit_result.get("correction", Vector3.ONE) as Vector3).is_zero_approx())

	var outside_exit_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.575, 0.5), 10.0)
	var outside_exit_result: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
		camera,
		outside_exit_follow,
		desired_transform,
		soft_zone,
		0.016,
		inside_exit_state
	)
	var outside_exit_state: Dictionary = outside_exit_result.get("dead_zone_state", {})
	assert_false(bool(outside_exit_state.get("x", true)))
	assert_true((outside_exit_result.get("correction", Vector3.ZERO) as Vector3).length() > 0.000001)

func test_hysteresis_entry_threshold_uses_dead_zone_minus_margin() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 2.0, 0.02)
	var state: Dictionary = {"x": false, "y": false}

	var outside_entry_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.535, 0.5), 10.0)
	var outside_entry_result: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
		camera,
		outside_entry_follow,
		desired_transform,
		soft_zone,
		0.016,
		state
	)
	var outside_entry_state: Dictionary = outside_entry_result.get("dead_zone_state", {})
	assert_false(bool(outside_entry_state.get("x", true)))

	var inside_entry_follow: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.525, 0.5), 10.0)
	var inside_entry_result: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
		camera,
		inside_entry_follow,
		desired_transform,
		soft_zone,
		0.016,
		outside_entry_state
	)
	var inside_entry_state: Dictionary = inside_entry_result.get("dead_zone_state", {})
	assert_true(bool(inside_entry_state.get("x", false)))
	assert_true((inside_entry_result.get("correction", Vector3.ONE) as Vector3).is_zero_approx())

func test_hysteresis_prevents_boundary_oscillation_toggling() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 2.0, 0.02)
	var state: Dictionary = {"x": true, "y": true}
	var inputs: Array[float] = [0.549, 0.551, 0.549, 0.551, 0.549, 0.551]

	for normalized_x in inputs:
		var follow_world_pos: Vector3 = _world_from_normalized(
			camera,
			desired_transform,
			Vector2(normalized_x, 0.5),
			10.0
		)
		var result: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
			camera,
			follow_world_pos,
			desired_transform,
			soft_zone,
			0.016,
			state
		)
		state = result.get("dead_zone_state", {})
		assert_true(bool(state.get("x", false)))
		assert_true((result.get("correction", Vector3.ONE) as Vector3).is_zero_approx())

func test_zero_hysteresis_margin_matches_non_hysteresis_behavior() -> void:
	var camera: Camera3D = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var soft_zone: Resource = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 2.0, 0.0)
	var follow_world_pos: Vector3 = _world_from_normalized(camera, desired_transform, Vector2(0.56, 0.5), 10.0)

	var from_in_dead: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016,
		{"x": true, "y": true}
	)
	var from_outside_dead: Dictionary = SOFT_ZONE_HELPER.compute_camera_correction_with_state(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		0.016,
		{"x": false, "y": false}
	)

	assert_eq(from_in_dead.get("dead_zone_state", {}), from_outside_dead.get("dead_zone_state", {}))
	assert_true(
		((from_in_dead.get("correction", Vector3.ZERO) as Vector3) - (from_outside_dead.get("correction", Vector3.ZERO) as Vector3)).length() <= 0.0001
	)
