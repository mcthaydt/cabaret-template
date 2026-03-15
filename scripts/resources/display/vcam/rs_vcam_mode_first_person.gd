@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamModeFirstPerson

const MIN_LOOK_MULTIPLIER: float = 0.0001
const MIN_FOV: float = 1.0
const MAX_FOV: float = 179.0
const DEFAULT_STRAFE_TILT_SMOOTHING: float = 6.0

@export var head_offset: Vector3 = Vector3(0.0, 1.7, 0.0)
@export var look_multiplier: float = 1.0
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0
@export var fov: float = 75.0
@export var strafe_tilt_angle: float = 0.0
@export var strafe_tilt_smoothing: float = DEFAULT_STRAFE_TILT_SMOOTHING

func get_resolved_values() -> Dictionary:
	var resolved_pitch_min: float = minf(pitch_min, pitch_max)
	var resolved_pitch_max: float = maxf(pitch_min, pitch_max)
	return {
		"head_offset": head_offset,
		"look_multiplier": maxf(look_multiplier, MIN_LOOK_MULTIPLIER),
		"pitch_min": resolved_pitch_min,
		"pitch_max": resolved_pitch_max,
		"fov": clampf(fov, MIN_FOV, MAX_FOV),
		"strafe_tilt_angle": maxf(strafe_tilt_angle, 0.0),
		"strafe_tilt_smoothing": maxf(strafe_tilt_smoothing, 0.0),
	}
