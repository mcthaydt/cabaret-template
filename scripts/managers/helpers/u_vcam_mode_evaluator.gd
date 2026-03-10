extends RefCounted
class_name U_VCamModeEvaluator

const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const MIN_DIRECTION_LENGTH_SQUARED: float = 0.000001
const PARALLEL_UP_DOT_THRESHOLD: float = 0.999

static func evaluate(
	mode: Resource,
	follow_target: Node3D,
	look_at_target: Node3D,
	runtime_yaw: float,
	runtime_pitch: float,
	_fixed_anchor: Node3D = null
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

	var distance: float = float(mode.get("distance"))
	if distance <= 0.0:
		return {}

	var total_yaw: float = float(mode.get("authored_yaw"))
	var total_pitch: float = float(mode.get("authored_pitch"))
	if bool(mode.get("allow_player_rotation")):
		total_yaw += runtime_yaw
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
		"fov": float(mode.get("fov")),
		"mode_name": "orbit",
	}
