extends RefCounted
class_name U_VCamModeEvaluator

const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")
const MIN_DIRECTION_LENGTH_SQUARED: float = 0.000001
const PARALLEL_UP_DOT_THRESHOLD: float = 0.999

static func evaluate(
	mode: Resource,
	follow_target: Node3D,
	look_at_target: Node3D,
	runtime_yaw: float,
	runtime_pitch: float
) -> Dictionary:
	if mode == null:
		return {}

	if mode.get_script() == RS_VCAM_MODE_ORBIT_SCRIPT:
		return _evaluate_orbit(mode, follow_target, look_at_target, runtime_yaw, runtime_pitch)

	return {}

static func _evaluate_orbit(
	mode: Resource,
	follow_target: Node3D,
	look_at_target: Node3D,
	runtime_yaw: float,
	runtime_pitch: float
) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {}

	var resolved_values: Dictionary = _resolve_orbit_values(mode)
	var distance: float = float(resolved_values.get("distance", 0.0))
	if distance <= 0.0:
		return {}

	var total_yaw: float = float(resolved_values.get("authored_yaw", 0.0))
	var total_pitch: float = float(resolved_values.get("authored_pitch", 0.0))
	if bool(resolved_values.get("allow_player_rotation", true)):
		if not bool(resolved_values.get("lock_x_rotation", false)):
			total_yaw += runtime_yaw
		if not bool(resolved_values.get("lock_y_rotation", true)):
			total_pitch += runtime_pitch

	var pitch_rad: float = deg_to_rad(total_pitch)
	var yaw_rad: float = deg_to_rad(total_yaw)
	var offset := Vector3(
		distance * cos(pitch_rad) * sin(yaw_rad),
		-distance * sin(pitch_rad),
		distance * cos(pitch_rad) * cos(yaw_rad)
	)

	var follow_position: Vector3 = follow_target.global_position
	var camera_position: Vector3 = follow_position + offset
	var look_target_position: Vector3 = follow_position
	if look_at_target != null and is_instance_valid(look_at_target):
		look_target_position = look_at_target.global_position

	var direction_to_target: Vector3 = look_target_position - camera_position
	if direction_to_target.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return {}

	var forward_dir: Vector3 = direction_to_target.normalized()
	var up_vector: Vector3 = Vector3.UP
	if absf(forward_dir.dot(up_vector)) >= PARALLEL_UP_DOT_THRESHOLD:
		up_vector = Vector3.FORWARD

	var camera_transform: Transform3D = Transform3D(Basis.IDENTITY, camera_position).looking_at(
		look_target_position,
		up_vector
	)
	return {
		"transform": camera_transform,
		"fov": float(resolved_values.get("fov", 75.0)),
		"mode_name": "orbit",
	}

static func _resolve_orbit_values(mode: Resource) -> Dictionary:
	var resolved_values: Dictionary = {}
	if mode != null and mode.has_method("get_resolved_values"):
		var resolved_variant: Variant = mode.call("get_resolved_values")
		if resolved_variant is Dictionary:
			resolved_values = resolved_variant as Dictionary

	if resolved_values.is_empty():
		resolved_values = {
			"distance": float(mode.get("distance")),
			"authored_pitch": float(mode.get("authored_pitch")),
			"authored_yaw": float(mode.get("authored_yaw")),
			"allow_player_rotation": bool(mode.get("allow_player_rotation")),
			"lock_x_rotation": bool(mode.get("lock_x_rotation")) if "lock_x_rotation" in mode else false,
			"lock_y_rotation": bool(mode.get("lock_y_rotation")) if "lock_y_rotation" in mode else true,
			"fov": float(mode.get("fov")),
		}

	return resolved_values
