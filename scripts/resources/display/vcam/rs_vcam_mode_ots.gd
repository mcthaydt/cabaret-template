@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamModeOTS

const MIN_LOOK_MULTIPLIER: float = 0.0001
const MIN_POSITIVE_FREQUENCY: float = 0.0001
const MIN_AIM_BLEND_DURATION: float = 0.01
const MIN_FOV: float = 1.0
const MAX_FOV: float = 179.0
const DEFAULT_SHOULDER_SWAY_SMOOTHING: float = 6.0
const DEFAULT_LANDING_DIP_RECOVERY_SPEED: float = 6.0

@export var shoulder_offset: Vector3 = Vector3(0.3, 1.6, -0.5)
@export var camera_distance: float = 1.8
@export var pitch_position_influence: float = 0.2
@export var look_multiplier: float = 1.0
@export var pitch_min: float = -60.0
@export var pitch_max: float = 50.0
@export var fov: float = 60.0
@export var collision_probe_radius: float = 0.15
@export var collision_recovery_speed: float = 8.0
@export var shoulder_sway_angle: float = 0.0
@export var shoulder_sway_smoothing: float = DEFAULT_SHOULDER_SWAY_SMOOTHING
@export var landing_dip_distance: float = 0.0
@export var landing_dip_recovery_speed: float = DEFAULT_LANDING_DIP_RECOVERY_SPEED
@export var movement_profile: RS_MovementSettings = null
@export var disable_sprint: bool = true
@export var lock_facing_to_camera: bool = true
@export var aim_blend_duration: float = 0.35
@export var aim_exit_blend_duration: float = 0.2

func get_resolved_values() -> Dictionary:
	var resolved_pitch_min: float = minf(pitch_min, pitch_max)
	var resolved_pitch_max: float = maxf(pitch_min, pitch_max)
	return {
		"shoulder_offset": shoulder_offset,
		"camera_distance": maxf(camera_distance, 0.0),
		"pitch_position_influence": clampf(pitch_position_influence, 0.0, 1.0),
		"look_multiplier": maxf(look_multiplier, MIN_LOOK_MULTIPLIER),
		"pitch_min": resolved_pitch_min,
		"pitch_max": resolved_pitch_max,
		"fov": clampf(fov, MIN_FOV, MAX_FOV),
		"collision_probe_radius": maxf(collision_probe_radius, 0.0),
		"collision_recovery_speed": maxf(collision_recovery_speed, MIN_POSITIVE_FREQUENCY),
		"shoulder_sway_angle": maxf(shoulder_sway_angle, 0.0),
		"shoulder_sway_smoothing": maxf(shoulder_sway_smoothing, 0.0),
		"landing_dip_distance": maxf(landing_dip_distance, 0.0),
		"landing_dip_recovery_speed": maxf(landing_dip_recovery_speed, MIN_POSITIVE_FREQUENCY),
		"movement_profile": movement_profile,
		"disable_sprint": disable_sprint,
		"lock_facing_to_camera": lock_facing_to_camera,
		"aim_blend_duration": maxf(aim_blend_duration, MIN_AIM_BLEND_DURATION),
		"aim_exit_blend_duration": maxf(aim_exit_blend_duration, MIN_AIM_BLEND_DURATION),
	}
