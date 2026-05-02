extends RefCounted
class_name U_VCamRotation

## Thin coordinator that delegates to three decomposed helpers:
##   U_VCamRotationContinuity — rotation transitions on vCam switch
##   U_VCamOrbitCentering — orbit "look behind" centering animation
##   U_VCamLookSpring — 2nd-order spring dynamics + release damping + debug

const U_VCAM_ROTATION_CONTINUITY := preload("res://scripts/core/ecs/systems/helpers/u_vcam_rotation_continuity.gd")
const U_VCAM_ORBIT_CENTERING := preload("res://scripts/core/ecs/systems/helpers/u_vcam_orbit_centering.gd")
const U_VCAM_LOOK_SPRING := preload("res://scripts/core/ecs/systems/helpers/u_vcam_look_spring.gd")

var _continuity_helper := U_VCAM_ROTATION_CONTINUITY.new()
var _orbit_centering_helper := U_VCAM_ORBIT_CENTERING.new()
var _look_spring_helper := U_VCAM_LOOK_SPRING.new()
var _orbit_no_look_input_timers: Dictionary = {}  # StringName -> float seconds

var debug_enabled: bool = false:
	set(value):
		debug_enabled = value
		_look_spring_helper.debug_enabled = value

func apply_rotation_continuity_policy(
	active_vcam_id: StringName,
	vcam_index: Dictionary,
	previous_vcam_id: StringName,
	last_active_vcam_id: StringName,
	resolve_follow_target: Callable,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> StringName:
	return _continuity_helper.apply_rotation_continuity_policy(
		active_vcam_id,
		vcam_index,
		previous_vcam_id,
		last_active_vcam_id,
		resolve_follow_target,
		resolve_mode_values,
		orbit_mode_script
	)

func update_runtime_rotation(
	vcam_id: StringName,
	component: Object,
	mode: Resource,
	follow_target: Node3D,
	look_input: Vector2,
	has_look_input: bool,
	camera_center_just_pressed: bool,
	response_values: Dictionary,
	delta: float,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> void:
	if component == null or mode == null:
		return

	var mode_script := mode.get_script() as Script
	if mode_script != orbit_mode_script:
		_orbit_no_look_input_timers.erase(vcam_id)
		_orbit_centering_helper.clear_centering_state_for_vcam(vcam_id)
		return

	var orbit_values: Dictionary = _resolve_orbit_mode_values(mode, resolve_mode_values)
	if not bool(orbit_values.get("allow_player_rotation", true)):
		_orbit_no_look_input_timers.erase(vcam_id)
		_orbit_centering_helper.clear_centering_state_for_vcam(vcam_id)
		return

	var lock_x_rotation: bool = bool(orbit_values.get("lock_x_rotation", false))
	var lock_y_rotation: bool = bool(orbit_values.get("lock_y_rotation", true))
	if lock_x_rotation:
		component.runtime_yaw = 0.0
		_orbit_centering_helper.clear_centering_state_for_vcam(vcam_id)
	if lock_y_rotation:
		component.runtime_pitch = 0.0

	if camera_center_just_pressed and not lock_x_rotation:
		_orbit_centering_helper.start_orbit_centering(
			vcam_id, component, mode, follow_target,
			resolve_mode_values, orbit_mode_script
		)
	if _orbit_centering_helper.step_orbit_centering(vcam_id, component, delta):
		_orbit_no_look_input_timers[vcam_id] = 0.0
		return

	var rotation_speed: float = maxf(float(orbit_values.get("rotation_speed", 0.0)), 0.0)
	if has_look_input:
		if not lock_x_rotation:
			component.runtime_yaw += look_input.x * rotation_speed
		if not lock_y_rotation:
			component.runtime_pitch += look_input.y * rotation_speed
		_orbit_no_look_input_timers[vcam_id] = 0.0
		return
	if lock_y_rotation:
		_orbit_no_look_input_timers.erase(vcam_id)
		return

	var no_look_timer: float = float(_orbit_no_look_input_timers.get(vcam_id, 0.0))
	no_look_timer += maxf(delta, 0.0)
	_orbit_no_look_input_timers[vcam_id] = no_look_timer

	var auto_level_speed: float = maxf(float(response_values.get("auto_level_speed", 0.0)), 0.0)
	if auto_level_speed <= 0.0:
		return
	var auto_level_delay: float = maxf(float(response_values.get("auto_level_delay", 1.0)), 0.0)
	if no_look_timer < auto_level_delay:
		return
	component.runtime_pitch = move_toward(
		component.runtime_pitch,
		0.0,
		auto_level_speed * maxf(delta, 0.0)
	)

func resolve_runtime_rotation_for_evaluation(
	vcam_id: StringName,
	component: Object,
	mode: Resource,
	follow_target: Node3D,
	response_values: Dictionary,
	response_signature: Array[float],
	has_active_look_input: bool,
	delta: float,
	orbit_mode_script: Script
) -> Vector2:
	return _look_spring_helper.resolve_runtime_rotation_for_evaluation(
		vcam_id,
		component,
		mode,
		follow_target,
		response_values,
		response_signature,
		has_active_look_input,
		delta,
		orbit_mode_script
	)

func step_orbit_release_axis(
	current_value: float,
	target_value: float,
	current_velocity: float,
	frequency_hz: float,
	damping_ratio: float,
	release_damping: float,
	stop_threshold: float,
	delta: float
) -> Dictionary:
	return _look_spring_helper.step_orbit_release_axis(
		current_value,
		target_value,
		current_velocity,
		frequency_hz,
		damping_ratio,
		release_damping,
		stop_threshold,
		delta
	)

func resolve_orbit_center_target_yaw(
	mode: Resource,
	follow_target: Node3D,
	current_runtime_yaw: float,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> float:
	return _orbit_centering_helper.resolve_orbit_center_target_yaw(
		mode,
		follow_target,
		current_runtime_yaw,
		resolve_mode_values,
		orbit_mode_script
	)

func is_orbit_centering_active(vcam_id: StringName) -> bool:
	return _orbit_centering_helper.is_orbit_centering_active(vcam_id)

func prune(active_vcam_ids: Array) -> void:
	_look_spring_helper.prune(active_vcam_ids)
	_orbit_centering_helper.prune(active_vcam_ids)
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _orbit_no_look_input_timers.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_orbit_no_look_input_timers.erase(vcam_id)

func clear_all() -> void:
	_look_spring_helper.clear_all()
	_orbit_no_look_input_timers.clear()
	_orbit_centering_helper.clear_all()

func clear_rotation_state_for_vcam(vcam_id: StringName) -> void:
	_look_spring_helper.clear_rotation_state_for_vcam(vcam_id)
	_orbit_no_look_input_timers.erase(vcam_id)

func clear_centering_state_for_vcam(vcam_id: StringName) -> void:
	_orbit_centering_helper.clear_centering_state_for_vcam(vcam_id)

func clear_for_vcam(vcam_id: StringName) -> void:
	clear_rotation_state_for_vcam(vcam_id)
	clear_centering_state_for_vcam(vcam_id)

func get_look_rotation_state_snapshot() -> Dictionary:
	return _look_spring_helper.get_look_rotation_state_snapshot()

func get_orbit_centering_state_snapshot() -> Dictionary:
	return _orbit_centering_helper.get_orbit_centering_state_snapshot()

func get_orbit_no_look_input_timers_snapshot() -> Dictionary:
	return _orbit_no_look_input_timers.duplicate(true)

func _resolve_orbit_mode_values(mode: Resource, resolve_mode_values: Callable) -> Dictionary:
	if mode == null or not resolve_mode_values.is_valid():
		return {
			"allow_player_rotation": true,
			"lock_x_rotation": false,
			"lock_y_rotation": true,
			"rotation_speed": 0.0,
		}
	var values_variant: Variant = resolve_mode_values.call(mode, {
		"allow_player_rotation": true,
		"lock_x_rotation": false,
		"lock_y_rotation": true,
		"rotation_speed": 0.0,
	})
	if values_variant is Dictionary:
		return (values_variant as Dictionary).duplicate(true)
	return {
		"allow_player_rotation": true,
		"lock_x_rotation": false,
		"lock_y_rotation": true,
		"rotation_speed": 0.0,
	}