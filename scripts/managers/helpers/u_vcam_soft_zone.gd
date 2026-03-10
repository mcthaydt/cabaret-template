extends RefCounted
class_name U_VCamSoftZone

const MIN_VIEWPORT_SIZE: float = 1.0
const CENTER_NORM: float = 0.5
const EPSILON: float = 0.000001

static func compute_camera_correction(
	camera: Camera3D,
	follow_world_pos: Vector3,
	desired_transform: Transform3D,
	soft_zone: Resource,
	delta: float
) -> Vector3:
	var result: Dictionary = compute_camera_correction_with_state(
		camera,
		follow_world_pos,
		desired_transform,
		soft_zone,
		delta
	)
	var correction_variant: Variant = result.get("correction", Vector3.ZERO)
	if correction_variant is Vector3:
		return correction_variant as Vector3
	return Vector3.ZERO

static func compute_camera_correction_with_state(
	camera: Camera3D,
	follow_world_pos: Vector3,
	desired_transform: Transform3D,
	soft_zone: Resource,
	delta: float,
	dead_zone_state: Dictionary = {}
) -> Dictionary:
	var next_dead_zone_state: Dictionary = {
		"x": bool(dead_zone_state.get("x", false)),
		"y": bool(dead_zone_state.get("y", false)),
	}
	var result: Dictionary = {
		"correction": Vector3.ZERO,
		"dead_zone_state": next_dead_zone_state,
	}
	if camera == null or not is_instance_valid(camera):
		return result
	if soft_zone == null:
		return result

	var viewport: Viewport = camera.get_viewport()
	if viewport == null:
		return result
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= MIN_VIEWPORT_SIZE or viewport_size.y <= MIN_VIEWPORT_SIZE:
		return result

	var resolved_values: Dictionary = _resolve_soft_zone_values(soft_zone)
	var dead_half_x: float = float(resolved_values.get("dead_zone_width", 0.0)) * 0.5
	var dead_half_y: float = float(resolved_values.get("dead_zone_height", 0.0)) * 0.5
	var soft_half_x: float = float(resolved_values.get("soft_zone_width", 0.0)) * 0.5
	var soft_half_y: float = float(resolved_values.get("soft_zone_height", 0.0)) * 0.5
	var damping_alpha: float = clampf(
		float(resolved_values.get("damping", 0.0)) * maxf(delta, 0.0),
		0.0,
		1.0
	)
	var hysteresis_margin: float = float(resolved_values.get("hysteresis_margin", 0.0))

	var desired_origin: Vector3 = desired_transform.origin
	var desired_forward: Vector3 = -desired_transform.basis.z
	var depth: float = (follow_world_pos - desired_origin).dot(desired_forward)
	if depth <= 0.0:
		return result

	var previous_transform: Transform3D = camera.global_transform
	camera.global_transform = desired_transform

	var screen_pos: Vector2 = camera.unproject_position(follow_world_pos)
	var normalized_screen_pos := Vector2(
		screen_pos.x / viewport_size.x,
		screen_pos.y / viewport_size.y
	)

	var axis_x_result: Dictionary = _resolve_axis(
		normalized_screen_pos.x,
		dead_half_x,
		soft_half_x,
		damping_alpha,
		hysteresis_margin,
		bool(next_dead_zone_state.get("x", false))
	)
	var axis_y_result: Dictionary = _resolve_axis(
		normalized_screen_pos.y,
		dead_half_y,
		soft_half_y,
		damping_alpha,
		hysteresis_margin,
		bool(next_dead_zone_state.get("y", false))
	)
	next_dead_zone_state["x"] = bool(axis_x_result.get("in_dead_zone", false))
	next_dead_zone_state["y"] = bool(axis_y_result.get("in_dead_zone", false))

	var corrected_normalized := Vector2(
		float(axis_x_result.get("value", normalized_screen_pos.x)),
		float(axis_y_result.get("value", normalized_screen_pos.y))
	)
	if corrected_normalized.distance_squared_to(normalized_screen_pos) > EPSILON:
		var corrected_screen := Vector2(
			corrected_normalized.x * viewport_size.x,
			corrected_normalized.y * viewport_size.y
		)
		var corrected_world: Vector3 = camera.project_position(corrected_screen, depth)
		result["correction"] = follow_world_pos - corrected_world

	camera.global_transform = previous_transform
	result["dead_zone_state"] = next_dead_zone_state
	return result

static func _resolve_soft_zone_values(soft_zone: Resource) -> Dictionary:
	var resolved_values: Dictionary = {}
	if soft_zone.has_method("get_resolved_values"):
		var resolved_variant: Variant = soft_zone.call("get_resolved_values")
		if resolved_variant is Dictionary:
			resolved_values = (resolved_variant as Dictionary).duplicate(true)

	if resolved_values.is_empty():
		var dead_zone_width: float = clampf(float(soft_zone.get("dead_zone_width")), 0.0, 1.0)
		var dead_zone_height: float = clampf(float(soft_zone.get("dead_zone_height")), 0.0, 1.0)
		var soft_zone_width: float = clampf(maxf(float(soft_zone.get("soft_zone_width")), dead_zone_width), 0.0, 1.0)
		var soft_zone_height: float = clampf(maxf(float(soft_zone.get("soft_zone_height")), dead_zone_height), 0.0, 1.0)
		resolved_values = {
			"dead_zone_width": dead_zone_width,
			"dead_zone_height": dead_zone_height,
			"soft_zone_width": soft_zone_width,
			"soft_zone_height": soft_zone_height,
			"damping": maxf(float(soft_zone.get("damping")), 0.0),
			"hysteresis_margin": maxf(float(soft_zone.get("hysteresis_margin")), 0.0),
		}
	return resolved_values

static func _resolve_axis(
	normalized_axis: float,
	dead_half: float,
	soft_half: float,
	damping_alpha: float,
	hysteresis_margin: float,
	was_in_dead_zone: bool
) -> Dictionary:
	var clamped_dead_half: float = clampf(dead_half, 0.0, CENTER_NORM)
	var clamped_soft_half: float = clampf(maxf(soft_half, clamped_dead_half), 0.0, CENTER_NORM)
	var clamped_margin: float = clampf(hysteresis_margin, 0.0, clamped_soft_half)

	var offset_from_center: float = normalized_axis - CENTER_NORM
	var abs_offset: float = absf(offset_from_center)
	var entry_threshold: float = maxf(clamped_dead_half - clamped_margin, 0.0)
	var exit_threshold: float = minf(clamped_dead_half + clamped_margin, clamped_soft_half)

	var in_dead_zone: bool
	if was_in_dead_zone:
		in_dead_zone = abs_offset <= exit_threshold
	else:
		in_dead_zone = abs_offset <= entry_threshold

	if in_dead_zone:
		return {
			"value": clampf(normalized_axis, 0.0, 1.0),
			"in_dead_zone": true,
		}

	var direction_sign: float = 1.0 if offset_from_center >= 0.0 else -1.0
	var corrected_value: float = normalized_axis
	if abs_offset <= clamped_soft_half + EPSILON:
		var dead_boundary: float = CENTER_NORM + (direction_sign * clamped_dead_half)
		corrected_value = lerpf(normalized_axis, dead_boundary, damping_alpha)
	else:
		var soft_boundary: float = CENTER_NORM + (direction_sign * clamped_soft_half)
		corrected_value = soft_boundary

	return {
		"value": clampf(corrected_value, 0.0, 1.0),
		"in_dead_zone": false,
	}
