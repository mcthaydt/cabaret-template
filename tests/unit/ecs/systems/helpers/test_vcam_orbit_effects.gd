extends GutTest

const U_VCAM_ORBIT_EFFECTS := preload("res://scripts/core/ecs/systems/helpers/u_vcam_orbit_effects.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_SOFT_ZONE := preload("res://scripts/core/resources/display/vcam/rs_vcam_soft_zone.gd")

var _velocity_sample: Dictionary = {"has_velocity": false, "velocity": Vector3.ZERO}
var _grounded: bool = false
var _ground_probe_result: Dictionary = {"valid": false, "height": 0.0}
var _projection_camera: Camera3D = null

func _new_orbit_mode() -> Resource:
	return RS_VCAM_MODE_ORBIT.new()

func _new_soft_zone(
	dead_zone_width: float = 0.1,
	dead_zone_height: float = 0.1,
	soft_zone_width: float = 0.4,
	soft_zone_height: float = 0.4,
	damping: float = 20.0,
	hysteresis_margin: float = 0.02
) -> Resource:
	var soft_zone := RS_VCAM_SOFT_ZONE.new()
	soft_zone.dead_zone_width = dead_zone_width
	soft_zone.dead_zone_height = dead_zone_height
	soft_zone.soft_zone_width = soft_zone_width
	soft_zone.soft_zone_height = soft_zone_height
	soft_zone.damping = damping
	soft_zone.hysteresis_margin = hysteresis_margin
	return soft_zone

func _response_values(
	look_ahead_distance: float = 2.0,
	look_ahead_smoothing: float = 0.0,
	ground_relative_enabled: bool = true
) -> Dictionary:
	return {
		"look_ahead_distance": look_ahead_distance,
		"look_ahead_smoothing": look_ahead_smoothing,
		"ground_relative_enabled": ground_relative_enabled,
		"ground_reanchor_min_height_delta": 0.5,
		"ground_probe_max_distance": 20.0,
		"ground_anchor_blend_hz": 0.0,
		"orbit_look_bypass_enable_speed": 1.0,
		"orbit_look_bypass_disable_speed": 2.0,
	}

func _resolve_look_ahead_velocity(_follow_target: Node3D) -> Dictionary:
	return _velocity_sample.duplicate(true)

func _resolve_grounded(_follow_target: Node3D) -> bool:
	return _grounded

func _probe_ground(_follow_target: Node3D, _max_distance: float) -> Dictionary:
	return _ground_probe_result.duplicate(true)

func _resolve_projection_camera() -> Camera3D:
	return _projection_camera

func _apply_position_offset(result: Dictionary, offset: Vector3) -> Dictionary:
	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result
	var transform := transform_variant as Transform3D
	var updated: Dictionary = result.duplicate(true)
	transform.origin += offset
	updated["transform"] = transform
	return updated

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

func test_look_ahead_applies_offset_in_planar_movement_direction() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_look_ahead")
	var mode := _new_orbit_mode()
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	var base_result := {"transform": Transform3D.IDENTITY}
	_velocity_sample = {"has_velocity": true, "velocity": Vector3(6.0, 0.0, 0.0)}

	var updated: Dictionary = helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		_response_values(2.0, 0.0),
		false,
		0.016,
		Callable(self, "_resolve_look_ahead_velocity"),
		Callable(self, "_apply_position_offset")
	)

	var transform := updated.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(transform.origin.x, 2.0, 0.0001)
	assert_almost_eq(transform.origin.y, 0.0, 0.0001)
	assert_almost_eq(transform.origin.z, 0.0, 0.0001)

func test_look_ahead_clears_state_when_look_input_is_active() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_look_input")
	var mode := _new_orbit_mode()
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	var base_result := {"transform": Transform3D.IDENTITY}
	_velocity_sample = {"has_velocity": true, "velocity": Vector3(4.0, 0.0, 0.0)}

	helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		_response_values(2.0, 0.0),
		false,
		0.016,
		Callable(self, "_resolve_look_ahead_velocity"),
		Callable(self, "_apply_position_offset")
	)
	assert_true(helper.get_look_ahead_state_snapshot().has(vcam_id))

	helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		_response_values(2.0, 0.0),
		true,
		0.016,
		Callable(self, "_resolve_look_ahead_velocity"),
		Callable(self, "_apply_position_offset")
	)
	assert_false(helper.get_look_ahead_state_snapshot().has(vcam_id))

func test_look_ahead_ignores_vertical_only_velocity() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_vertical_only")
	var mode := _new_orbit_mode()
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	var base_result := {"transform": Transform3D.IDENTITY}
	_velocity_sample = {"has_velocity": true, "velocity": Vector3(0.0, -5.0, 0.0)}

	var updated: Dictionary = helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		_response_values(2.0, 0.0),
		false,
		0.016,
		Callable(self, "_resolve_look_ahead_velocity"),
		Callable(self, "_apply_position_offset")
	)

	var transform := updated.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_true(transform.origin.is_zero_approx())
	var state := helper.get_look_ahead_state_snapshot().get(vcam_id, {}) as Dictionary
	assert_true((state.get("current_offset", Vector3.ONE) as Vector3).is_zero_approx())

func test_ground_relative_reanchors_on_landing_above_threshold() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_ground_reanchor")
	var mode := _new_orbit_mode()
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	var response_values: Dictionary = _response_values(0.0, 0.0, true)
	var base_result := {"transform": Transform3D.IDENTITY}

	follow_target.global_position = Vector3(0.0, 1.0, 0.0)
	_grounded = true
	_ground_probe_result = {"valid": true, "height": 0.0}
	helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		response_values,
		0.016,
		Callable(self, "_resolve_grounded"),
		Callable(self, "_probe_ground"),
		Callable(self, "_apply_position_offset")
	)

	follow_target.global_position = Vector3(0.0, 4.0, 0.0)
	_grounded = false
	_ground_probe_result = {"valid": true, "height": 10.0}
	helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		response_values,
		0.016,
		Callable(self, "_resolve_grounded"),
		Callable(self, "_probe_ground"),
		Callable(self, "_apply_position_offset")
	)

	follow_target.global_position = Vector3(0.0, 5.0, 0.0)
	_grounded = true
	_ground_probe_result = {"valid": true, "height": 2.0}
	helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		response_values,
		0.016,
		Callable(self, "_resolve_grounded"),
		Callable(self, "_probe_ground"),
		Callable(self, "_apply_position_offset")
	)

	var state := helper.get_ground_relative_state_snapshot().get(vcam_id, {}) as Dictionary
	assert_almost_eq(float(state.get("ground_anchor_target_y", -100.0)), 2.0, 0.0001)

func test_ground_relative_ignores_reanchor_while_airborne() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_ground_airborne")
	var mode := _new_orbit_mode()
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	var response_values: Dictionary = _response_values(0.0, 0.0, true)
	var base_result := {"transform": Transform3D.IDENTITY}

	follow_target.global_position = Vector3(0.0, 1.0, 0.0)
	_grounded = true
	_ground_probe_result = {"valid": true, "height": 0.0}
	helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		response_values,
		0.016,
		Callable(self, "_resolve_grounded"),
		Callable(self, "_probe_ground"),
		Callable(self, "_apply_position_offset")
	)

	follow_target.global_position = Vector3(0.0, 4.0, 0.0)
	_grounded = false
	_ground_probe_result = {"valid": true, "height": 8.0}
	helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		base_result,
		response_values,
		0.016,
		Callable(self, "_resolve_grounded"),
		Callable(self, "_probe_ground"),
		Callable(self, "_apply_position_offset")
	)

	var state := helper.get_ground_relative_state_snapshot().get(vcam_id, {}) as Dictionary
	assert_almost_eq(float(state.get("ground_anchor_target_y", -100.0)), 0.0, 0.0001)

func test_soft_zone_applies_non_zero_correction() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_soft_zone")
	var mode := _new_orbit_mode()
	_projection_camera = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_world: Vector3 = _world_from_normalized(
		_projection_camera,
		desired_transform,
		Vector2(0.62, 0.5),
		10.0
	)
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	follow_target.global_position = follow_world
	var base_result := {"transform": desired_transform}

	var updated: Dictionary = helper.apply_orbit_soft_zone(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		_new_soft_zone(),
		RS_VCAM_SOFT_ZONE,
		base_result,
		0.016,
		Callable(self, "_resolve_projection_camera"),
		Callable(self, "_apply_position_offset")
	)

	var transform := updated.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_true(transform.origin.length() > 0.0001)

func test_soft_zone_clears_dead_zone_state_for_non_orbit_mode() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_soft_zone_clear")
	var mode := _new_orbit_mode()
	_projection_camera = _create_projection_camera()
	var desired_transform := Transform3D.IDENTITY
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	follow_target.global_position = _world_from_normalized(
		_projection_camera,
		desired_transform,
		Vector2(0.62, 0.5),
		10.0
	)
	var base_result := {"transform": desired_transform}

	helper.apply_orbit_soft_zone(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT,
		follow_target,
		_new_soft_zone(),
		RS_VCAM_SOFT_ZONE,
		base_result,
		0.016,
		Callable(self, "_resolve_projection_camera"),
		Callable(self, "_apply_position_offset")
	)
	assert_true(helper.get_soft_zone_dead_zone_state_snapshot().has(vcam_id))

	helper.apply_orbit_soft_zone(
		vcam_id,
		Resource.new(),
		RS_VCAM_MODE_ORBIT,
		follow_target,
		_new_soft_zone(),
		RS_VCAM_SOFT_ZONE,
		base_result,
		0.016,
		Callable(self, "_resolve_projection_camera"),
		Callable(self, "_apply_position_offset")
	)
	assert_false(helper.get_soft_zone_dead_zone_state_snapshot().has(vcam_id))

func test_sample_follow_target_speed_uses_horizontal_displacement_only() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_speed")
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)

	follow_target.global_position = Vector3.ZERO
	assert_almost_eq(helper.sample_follow_target_speed(vcam_id, follow_target, 0.1), 0.0, 0.0001)
	follow_target.global_position = Vector3(1.0, 5.0, 0.0)
	assert_almost_eq(helper.sample_follow_target_speed(vcam_id, follow_target, 0.1), 10.0, 0.001)

func test_sample_follow_target_speed_resets_when_target_changes() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_speed_reset")
	var first_target := Node3D.new()
	var second_target := Node3D.new()
	add_child_autofree(first_target)
	add_child_autofree(second_target)

	first_target.global_position = Vector3.ZERO
	helper.sample_follow_target_speed(vcam_id, first_target, 0.1)
	first_target.global_position = Vector3(0.5, 0.0, 0.0)
	assert_true(helper.sample_follow_target_speed(vcam_id, first_target, 0.1) > 0.0)
	second_target.global_position = Vector3(20.0, 0.0, 0.0)
	assert_almost_eq(helper.sample_follow_target_speed(vcam_id, second_target, 0.1), 0.0, 0.0001)

func test_update_orbit_position_smoothing_bypass_uses_hysteresis() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var vcam_id := StringName("cam_bypass")
	var mode_script: Script = RS_VCAM_MODE_ORBIT
	var response_values: Dictionary = _response_values()

	var first: Dictionary = helper.update_orbit_position_smoothing_bypass(
		vcam_id,
		mode_script,
		RS_VCAM_MODE_ORBIT,
		true,
		0.8,
		response_values
	)
	assert_true(bool(first.get("bypass", false)))

	var held: Dictionary = helper.update_orbit_position_smoothing_bypass(
		vcam_id,
		mode_script,
		RS_VCAM_MODE_ORBIT,
		true,
		1.5,
		response_values
	)
	assert_true(bool(held.get("bypass", false)))

	var released: Dictionary = helper.update_orbit_position_smoothing_bypass(
		vcam_id,
		mode_script,
		RS_VCAM_MODE_ORBIT,
		true,
		2.5,
		response_values
	)
	assert_false(bool(released.get("bypass", true)))

func test_prune_and_clear_lifecycle_removes_stale_state() -> void:
	var helper := U_VCAM_ORBIT_EFFECTS.new()
	var orbit_mode := _new_orbit_mode()
	var follow_a := Node3D.new()
	var follow_b := Node3D.new()
	add_child_autofree(follow_a)
	add_child_autofree(follow_b)
	_velocity_sample = {"has_velocity": true, "velocity": Vector3(3.0, 0.0, 0.0)}

	helper.apply_orbit_look_ahead(
		StringName("cam_a"),
		orbit_mode,
		RS_VCAM_MODE_ORBIT,
		follow_a,
		{"transform": Transform3D.IDENTITY},
		_response_values(2.0, 0.0),
		false,
		0.016,
		Callable(self, "_resolve_look_ahead_velocity"),
		Callable(self, "_apply_position_offset")
	)
	helper.apply_orbit_look_ahead(
		StringName("cam_b"),
		orbit_mode,
		RS_VCAM_MODE_ORBIT,
		follow_b,
		{"transform": Transform3D.IDENTITY},
		_response_values(2.0, 0.0),
		false,
		0.016,
		Callable(self, "_resolve_look_ahead_velocity"),
		Callable(self, "_apply_position_offset")
	)

	helper.prune([StringName("cam_a")])
	assert_true(helper.get_look_ahead_state_snapshot().has(StringName("cam_a")))
	assert_false(helper.get_look_ahead_state_snapshot().has(StringName("cam_b")))

	helper.clear_for_vcam(StringName("cam_a"))
	assert_false(helper.get_look_ahead_state_snapshot().has(StringName("cam_a")))

	helper.clear_all()
	assert_true(helper.get_look_ahead_state_snapshot().is_empty())
	assert_true(helper.get_ground_relative_state_snapshot().is_empty())
	assert_true(helper.get_follow_target_motion_state_snapshot().is_empty())
	assert_true(helper.get_soft_zone_dead_zone_state_snapshot().is_empty())
	assert_true(helper.get_position_smoothing_bypass_snapshot().is_empty())
