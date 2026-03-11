@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamResponse

const MIN_FREQUENCY_HZ: float = 0.0001

@export var follow_frequency: float = 3.0
@export var follow_damping: float = 0.7
@export var follow_initial_response: float = 1.0

@export var rotation_frequency: float = 4.0
@export var rotation_damping: float = 1.0
@export var rotation_initial_response: float = 1.0
@export var look_ahead_distance: float = 0.0
@export var look_ahead_smoothing: float = 3.0
@export var auto_level_speed: float = 0.0
@export var auto_level_delay: float = 1.0
@export var look_input_deadzone: float = 0.02
@export var look_input_hold_sec: float = 0.06
@export var look_input_release_decay: float = 25.0
@export var orbit_look_bypass_enable_speed: float = 0.15
@export var orbit_look_bypass_disable_speed: float = 0.3
@export var ground_relative_enabled: bool = false
@export var ground_reanchor_min_height_delta: float = 0.5
@export var ground_probe_max_distance: float = 12.0
@export var ground_anchor_blend_hz: float = 4.0

func get_resolved_values() -> Dictionary:
	var resolved_orbit_bypass_enable_speed: float = maxf(orbit_look_bypass_enable_speed, 0.0)
	var resolved_orbit_bypass_disable_speed: float = maxf(
		orbit_look_bypass_disable_speed,
		resolved_orbit_bypass_enable_speed
	)
	return {
		"follow_frequency": maxf(follow_frequency, MIN_FREQUENCY_HZ),
		"follow_damping": maxf(follow_damping, 0.0),
		"follow_initial_response": follow_initial_response,
		"rotation_frequency": maxf(rotation_frequency, MIN_FREQUENCY_HZ),
		"rotation_damping": maxf(rotation_damping, 0.0),
		"rotation_initial_response": rotation_initial_response,
		"look_ahead_distance": maxf(look_ahead_distance, 0.0),
		"look_ahead_smoothing": maxf(look_ahead_smoothing, 0.0),
		"auto_level_speed": maxf(auto_level_speed, 0.0),
		"auto_level_delay": maxf(auto_level_delay, 0.0),
		"look_input_deadzone": maxf(look_input_deadzone, 0.0),
		"look_input_hold_sec": maxf(look_input_hold_sec, 0.0),
		"look_input_release_decay": maxf(look_input_release_decay, 0.0),
		"orbit_look_bypass_enable_speed": resolved_orbit_bypass_enable_speed,
		"orbit_look_bypass_disable_speed": resolved_orbit_bypass_disable_speed,
		"ground_relative_enabled": ground_relative_enabled,
		"ground_reanchor_min_height_delta": maxf(ground_reanchor_min_height_delta, 0.0),
		"ground_probe_max_distance": maxf(ground_probe_max_distance, 0.0),
		"ground_anchor_blend_hz": maxf(ground_anchor_blend_hz, 0.0),
	}
