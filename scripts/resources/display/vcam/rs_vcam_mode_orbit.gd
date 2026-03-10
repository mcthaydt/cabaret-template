@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamModeOrbit

const DEFAULT_AUTHORED_PITCH: float = -20.0
const DEFAULT_AUTHORED_YAW: float = 0.0
const DEFAULT_FOV: float = 75.0
const MIN_DISTANCE: float = 0.0
const MIN_FOV: float = 1.0
const MAX_FOV: float = 179.0

@export_range(0.01, 1000.0, 0.01) var distance: float = 5.0
@export_range(-90.0, 90.0, 0.01) var authored_pitch: float = DEFAULT_AUTHORED_PITCH
@export_range(-360.0, 360.0, 0.01) var authored_yaw: float = DEFAULT_AUTHORED_YAW
@export var allow_player_rotation: bool = true
@export_range(0.0, 20.0, 0.01) var rotation_speed: float = 2.0
@export_range(1.0, 179.0, 0.01) var fov: float = DEFAULT_FOV

func get_resolved_values() -> Dictionary:
	var resolved_distance: float = distance if not (is_nan(distance) or is_inf(distance)) else 0.0
	var resolved_pitch: float = authored_pitch if not (is_nan(authored_pitch) or is_inf(authored_pitch)) else DEFAULT_AUTHORED_PITCH
	var resolved_yaw: float = authored_yaw if not (is_nan(authored_yaw) or is_inf(authored_yaw)) else DEFAULT_AUTHORED_YAW
	var resolved_rotation_speed: float = rotation_speed if not (is_nan(rotation_speed) or is_inf(rotation_speed)) else 0.0
	var resolved_fov: float = fov if not (is_nan(fov) or is_inf(fov)) else DEFAULT_FOV
	return {
		"distance": maxf(resolved_distance, MIN_DISTANCE),
		"authored_pitch": resolved_pitch,
		"authored_yaw": resolved_yaw,
		"allow_player_rotation": allow_player_rotation,
		"rotation_speed": maxf(resolved_rotation_speed, 0.0),
		"fov": clampf(resolved_fov, MIN_FOV, MAX_FOV),
	}
