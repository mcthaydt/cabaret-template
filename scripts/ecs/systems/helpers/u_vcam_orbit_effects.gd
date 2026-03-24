extends RefCounted
class_name U_VCamOrbitEffects

const U_VCAM_SOFT_ZONE := preload("res://scripts/managers/helpers/u_vcam_soft_zone.gd")
const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/utils/math/u_second_order_dynamics_3d.gd")

const LOOK_AHEAD_MOVEMENT_EPSILON_SQ: float = 0.000001
const DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED: float = 0.15
const DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED: float = 0.3

var _look_ahead_state: Dictionary = {}  # StringName -> {follow_target_id, last_target_position, current_offset, smoothing_hz, dynamics}
var _ground_relative_state: Dictionary = {}  # StringName -> {initialized, follow_target_id, ground_anchor_y, ground_anchor_target_y, follow_anchor_y_offset, last_ground_reference_y, was_grounded, blend_hz, dynamics}
var _follow_target_motion_state: Dictionary = {}  # StringName -> {follow_target_id, last_position, speed_mps}
var _soft_zone_dead_zone_state: Dictionary = {}  # StringName -> {x: bool, y: bool}
var _position_smoothing_bypass_by_vcam: Dictionary = {}  # StringName -> bool

func apply_orbit_look_ahead(
	vcam_id: StringName,
	mode: Resource,
	orbit_mode_script: Script,
	follow_target: Node3D,
	result: Dictionary,
	response_values: Dictionary,
	has_active_look_input: bool,
	delta: float,
	resolve_look_ahead_velocity: Callable,
	apply_position_offset: Callable,
	debug_log_motion_state: Callable = Callable()
) -> Dictionary:
	if mode == null:
		clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if mode.get_script() != orbit_mode_script:
		clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if response_values.is_empty():
		clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var look_ahead_distance: float = maxf(float(response_values.get("look_ahead_distance", 0.0)), 0.0)
	if look_ahead_distance <= 0.0:
		clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if has_active_look_input:
		clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var target_id: int = follow_target.get_instance_id()
	if target_id == 0:
		clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var current_position: Vector3 = follow_target.global_position
	var state: Dictionary = _get_or_create_look_ahead_state(vcam_id, target_id, current_position)
	state["last_target_position"] = current_position

	var velocity_sample: Dictionary = {"has_velocity": false, "velocity": Vector3.ZERO}
	if resolve_look_ahead_velocity.is_valid():
		var velocity_sample_variant: Variant = resolve_look_ahead_velocity.call(follow_target)
		if velocity_sample_variant is Dictionary:
			velocity_sample = (velocity_sample_variant as Dictionary).duplicate(true)
	var has_velocity: bool = bool(velocity_sample.get("has_velocity", false))
	var velocity: Vector3 = Vector3.ZERO
	var velocity_variant: Variant = velocity_sample.get("velocity", Vector3.ZERO)
	if velocity_variant is Vector3:
		velocity = velocity_variant as Vector3

	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if (not has_velocity) or planar_velocity.length_squared() <= LOOK_AHEAD_MOVEMENT_EPSILON_SQ:
		_call_debug_look_ahead_motion(
			debug_log_motion_state,
			vcam_id,
			false,
			follow_target,
			planar_velocity,
			Vector3.ZERO
		)
		state["current_offset"] = Vector3.ZERO
		state["dynamics"] = null
		state["smoothing_hz"] = -1.0
		_look_ahead_state[vcam_id] = state
		return result

	var desired_offset: Vector3 = planar_velocity.normalized() * look_ahead_distance
	_call_debug_look_ahead_motion(
		debug_log_motion_state,
		vcam_id,
		true,
		follow_target,
		planar_velocity,
		desired_offset
	)

	var smoothing_hz: float = maxf(float(response_values.get("look_ahead_smoothing", 3.0)), 0.0)
	var current_offset: Vector3 = state.get("current_offset", Vector3.ZERO) as Vector3
	var smoothed_offset: Vector3 = desired_offset
	if smoothing_hz > 0.0:
		var rebuild_dynamics: bool = (
			not state.has("dynamics")
			or state.get("dynamics", null) == null
			or not is_equal_approx(float(state.get("smoothing_hz", -1.0)), smoothing_hz)
		)
		if rebuild_dynamics:
			state["dynamics"] = U_SECOND_ORDER_DYNAMICS_3D.new(smoothing_hz, 1.0, 0.0, current_offset)
			state["smoothing_hz"] = smoothing_hz
		var dynamics = state.get("dynamics", null)
		if dynamics != null:
			smoothed_offset = dynamics.step(desired_offset, maxf(delta, 0.0))
	else:
		state["dynamics"] = null
		state["smoothing_hz"] = 0.0

	if smoothed_offset.length_squared() > (look_ahead_distance * look_ahead_distance):
		smoothed_offset = smoothed_offset.normalized() * look_ahead_distance

	state["current_offset"] = smoothed_offset
	_look_ahead_state[vcam_id] = state

	if smoothed_offset.is_zero_approx():
		return result
	return _call_apply_position_offset(apply_position_offset, result, smoothed_offset)

func apply_orbit_ground_relative(
	vcam_id: StringName,
	mode: Resource,
	orbit_mode_script: Script,
	follow_target: Node3D,
	result: Dictionary,
	response_values: Dictionary,
	delta: float,
	resolve_grounded_state: Callable,
	probe_ground_reference_height: Callable,
	apply_position_offset: Callable
) -> Dictionary:
	if mode == null:
		clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if mode.get_script() != orbit_mode_script:
		clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if response_values.is_empty():
		clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if not bool(response_values.get("ground_relative_enabled", false)):
		clear_ground_relative_state_for_vcam(vcam_id)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result

	var follow_target_id: int = follow_target.get_instance_id()
	if follow_target_id == 0:
		clear_ground_relative_state_for_vcam(vcam_id)
		return result

	var follow_y: float = follow_target.global_position.y
	var state: Dictionary = _get_or_create_ground_relative_state(vcam_id, follow_target_id, follow_y)

	var grounded: bool = false
	if resolve_grounded_state.is_valid():
		grounded = bool(resolve_grounded_state.call(follow_target))
	var probe_max_distance: float = maxf(float(response_values.get("ground_probe_max_distance", 0.0)), 0.0)
	var ground_reference_y: float = follow_y
	var has_ground_reference: bool = false
	if grounded and probe_ground_reference_height.is_valid():
		var probe_result_variant: Variant = probe_ground_reference_height.call(follow_target, probe_max_distance)
		if probe_result_variant is Dictionary:
			var probe_result := probe_result_variant as Dictionary
			has_ground_reference = bool(probe_result.get("valid", false))
			if has_ground_reference:
				ground_reference_y = float(probe_result.get("height", follow_y))

	var initialized: bool = bool(state.get("initialized", false))
	var ground_anchor_y: float = float(state.get("ground_anchor_y", follow_y))
	var ground_anchor_target_y: float = float(state.get("ground_anchor_target_y", ground_anchor_y))
	var follow_anchor_y_offset: float = float(state.get("follow_anchor_y_offset", 0.0))
	var last_ground_reference_y: float = float(state.get("last_ground_reference_y", ground_anchor_target_y))
	var was_grounded: bool = bool(state.get("was_grounded", grounded))
	var blend_hz: float = maxf(float(response_values.get("ground_anchor_blend_hz", 0.0)), 0.0)
	var previous_blend_hz: float = float(state.get("blend_hz", -1.0))
	var dynamics: Variant = state.get("dynamics", null)
	var reset_dynamics: bool = false
	if not initialized:
		if grounded and has_ground_reference:
			ground_anchor_y = ground_reference_y
			ground_anchor_target_y = ground_reference_y
			follow_anchor_y_offset = follow_y - ground_reference_y
			last_ground_reference_y = ground_reference_y
			initialized = true
			reset_dynamics = true
		else:
			ground_anchor_y = follow_y
			ground_anchor_target_y = follow_y
			follow_anchor_y_offset = 0.0
			dynamics = null
			state["initialized"] = false
			state["follow_target_id"] = follow_target_id
			state["ground_anchor_y"] = ground_anchor_y
			state["ground_anchor_target_y"] = ground_anchor_target_y
			state["follow_anchor_y_offset"] = follow_anchor_y_offset
			state["last_ground_reference_y"] = last_ground_reference_y
			state["was_grounded"] = grounded
			state["blend_hz"] = blend_hz
			state["dynamics"] = dynamics
			_ground_relative_state[vcam_id] = state
			return result
	elif grounded and has_ground_reference and not was_grounded:
		var reanchor_min_height_delta: float = maxf(
			float(response_values.get("ground_reanchor_min_height_delta", 0.0)),
			0.0
		)
		var landing_height_delta: float = absf(ground_reference_y - last_ground_reference_y)
		if landing_height_delta >= reanchor_min_height_delta:
			ground_anchor_target_y = ground_reference_y
			follow_anchor_y_offset = follow_y - ground_reference_y
			last_ground_reference_y = ground_reference_y
			reset_dynamics = true

	if blend_hz <= 0.0:
		dynamics = null
		ground_anchor_y = ground_anchor_target_y
	else:
		var needs_rebuild: bool = (
			dynamics == null
			or not is_equal_approx(previous_blend_hz, blend_hz)
			or reset_dynamics
		)
		if needs_rebuild:
			dynamics = U_SECOND_ORDER_DYNAMICS.new(blend_hz, 1.0, 1.0, ground_anchor_y)
		if delta > 0.0 and dynamics != null:
			ground_anchor_y = float(dynamics.step(ground_anchor_target_y, delta))
		else:
			ground_anchor_y = ground_anchor_target_y
	if is_nan(ground_anchor_y) or is_inf(ground_anchor_y):
		ground_anchor_y = ground_anchor_target_y
	if is_nan(ground_anchor_target_y) or is_inf(ground_anchor_target_y):
		ground_anchor_target_y = ground_anchor_y

	state["initialized"] = initialized
	state["follow_target_id"] = follow_target_id
	state["ground_anchor_y"] = ground_anchor_y
	state["ground_anchor_target_y"] = ground_anchor_target_y
	state["follow_anchor_y_offset"] = follow_anchor_y_offset
	state["last_ground_reference_y"] = last_ground_reference_y
	state["was_grounded"] = grounded
	state["blend_hz"] = blend_hz
	state["dynamics"] = dynamics
	_ground_relative_state[vcam_id] = state

	var anchored_follow_y: float = ground_anchor_y + follow_anchor_y_offset
	var y_offset: float = anchored_follow_y - follow_y
	if absf(y_offset) <= 0.000001:
		return result
	return _call_apply_position_offset(apply_position_offset, result, Vector3(0.0, y_offset, 0.0))

func apply_orbit_soft_zone(
	vcam_id: StringName,
	mode: Resource,
	orbit_mode_script: Script,
	follow_target: Node3D,
	soft_zone: Resource,
	soft_zone_script: Script,
	result: Dictionary,
	delta: float,
	resolve_projection_camera: Callable,
	apply_position_offset: Callable,
	debug_log_soft_zone_status: Callable = Callable(),
	debug_log_soft_zone_metrics: Callable = Callable()
) -> Dictionary:
	if mode == null:
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_missing_component_or_mode",
			Vector3.ZERO
		)
		return result
	if mode.get_script() != orbit_mode_script:
		clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_non_orbit_mode",
			Vector3.ZERO
		)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_missing_follow_target",
			Vector3.ZERO
		)
		return result
	if soft_zone == null:
		clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_no_soft_zone_resource",
			Vector3.ZERO
		)
		return result
	if soft_zone.get_script() != soft_zone_script:
		clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_invalid_soft_zone_resource",
			Vector3.ZERO
		)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_missing_transform",
			Vector3.ZERO
		)
		return result
	var desired_transform := transform_variant as Transform3D

	var projection_camera: Camera3D = null
	if resolve_projection_camera.is_valid():
		var projection_variant: Variant = resolve_projection_camera.call()
		if projection_variant is Camera3D:
			projection_camera = projection_variant as Camera3D
	if projection_camera == null or not is_instance_valid(projection_camera):
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"skipped_missing_projection_camera",
			Vector3.ZERO
		)
		return result

	var dead_zone_state: Dictionary = get_soft_zone_dead_zone_state(vcam_id)
	var correction_result: Dictionary = U_VCAM_SOFT_ZONE.compute_camera_correction_with_state(
		projection_camera,
		follow_target.global_position,
		desired_transform,
		soft_zone,
		delta,
		dead_zone_state
	)
	var next_state_variant: Variant = correction_result.get("dead_zone_state", dead_zone_state)
	if next_state_variant is Dictionary:
		_soft_zone_dead_zone_state[vcam_id] = (next_state_variant as Dictionary).duplicate(true)
	var correction_variant: Variant = correction_result.get("correction", Vector3.ZERO)
	if not (correction_variant is Vector3):
		return result
	var correction := correction_variant as Vector3
	_call_debug_soft_zone_metrics(debug_log_soft_zone_metrics, vcam_id, correction_result, correction)
	if correction.is_zero_approx():
		_call_debug_soft_zone_status(
			debug_log_soft_zone_status,
			vcam_id,
			"inactive_zero_correction",
			correction
		)
		return result
	_call_debug_soft_zone_status(debug_log_soft_zone_status, vcam_id, "active_correction", correction)
	return _call_apply_position_offset(apply_position_offset, result, correction)

func sample_follow_target_speed(vcam_id: StringName, follow_target: Node3D, delta: float) -> float:
	if follow_target == null or not is_instance_valid(follow_target):
		_follow_target_motion_state.erase(vcam_id)
		return 0.0
	if delta <= 0.0:
		return 0.0

	var follow_target_id: int = follow_target.get_instance_id()
	if follow_target_id == 0:
		_follow_target_motion_state.erase(vcam_id)
		return 0.0

	var current_position: Vector3 = follow_target.global_position
	var state_variant: Variant = _follow_target_motion_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		_follow_target_motion_state[vcam_id] = {
			"follow_target_id": follow_target_id,
			"last_position": current_position,
			"speed_mps": 0.0,
		}
		return 0.0

	var state := (state_variant as Dictionary).duplicate(true)
	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if previous_target_id != follow_target_id:
		_follow_target_motion_state[vcam_id] = {
			"follow_target_id": follow_target_id,
			"last_position": current_position,
			"speed_mps": 0.0,
		}
		return 0.0

	var previous_position: Vector3 = state.get("last_position", current_position) as Vector3
	var displacement: Vector3 = current_position - previous_position
	var horizontal_displacement := Vector3(displacement.x, 0.0, displacement.z)
	var speed_mps: float = horizontal_displacement.length() / delta
	state["follow_target_id"] = follow_target_id
	state["last_position"] = current_position
	state["speed_mps"] = speed_mps
	_follow_target_motion_state[vcam_id] = state
	return speed_mps

func update_orbit_position_smoothing_bypass(
	vcam_id: StringName,
	mode_script: Script,
	orbit_mode_script: Script,
	has_active_look_input: bool,
	follow_target_speed_mps: float,
	response_values: Dictionary,
	default_enable_speed: float = DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED,
	default_disable_speed: float = DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED
) -> Dictionary:
	var enable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_enable_speed", default_enable_speed)),
		0.0
	)
	var disable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_disable_speed", default_disable_speed)),
		enable_speed
	)

	var had_previous: bool = _position_smoothing_bypass_by_vcam.has(vcam_id)
	var previous_bypass: bool = bool(_position_smoothing_bypass_by_vcam.get(vcam_id, false))
	var current_bypass: bool = _should_bypass_orbit_position_smoothing(
		mode_script,
		orbit_mode_script,
		has_active_look_input,
		follow_target_speed_mps,
		enable_speed,
		disable_speed,
		previous_bypass
	)
	_position_smoothing_bypass_by_vcam[vcam_id] = current_bypass

	return {
		"bypass": current_bypass,
		"previous_bypass": previous_bypass,
		"had_previous_bypass_state": had_previous,
		"enable_speed": enable_speed,
		"disable_speed": disable_speed,
	}

func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id == StringName(""):
			continue
		keep_ids[keep_id] = true

	var stale_ids: Array[StringName] = []
	for vcam_id_variant in _look_ahead_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _ground_relative_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _follow_target_motion_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _soft_zone_dead_zone_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _position_smoothing_bypass_by_vcam.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		clear_for_vcam(stale_id)

func clear_all() -> void:
	_look_ahead_state.clear()
	_ground_relative_state.clear()
	_follow_target_motion_state.clear()
	_soft_zone_dead_zone_state.clear()
	_position_smoothing_bypass_by_vcam.clear()

func clear_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_state.erase(vcam_id)
	_ground_relative_state.erase(vcam_id)
	_follow_target_motion_state.erase(vcam_id)
	_soft_zone_dead_zone_state.erase(vcam_id)
	_position_smoothing_bypass_by_vcam.erase(vcam_id)

func clear_look_ahead_state_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_state.erase(vcam_id)

func clear_ground_relative_state_for_vcam(vcam_id: StringName) -> void:
	_ground_relative_state.erase(vcam_id)

func clear_soft_zone_dead_zone_state_for_vcam(vcam_id: StringName) -> void:
	_soft_zone_dead_zone_state.erase(vcam_id)

func get_look_ahead_state_snapshot() -> Dictionary:
	return _look_ahead_state.duplicate(true)

func get_ground_relative_state_snapshot() -> Dictionary:
	return _ground_relative_state.duplicate(true)

func get_follow_target_motion_state_snapshot() -> Dictionary:
	return _follow_target_motion_state.duplicate(true)

func get_soft_zone_dead_zone_state_snapshot() -> Dictionary:
	return _soft_zone_dead_zone_state.duplicate(true)

func get_position_smoothing_bypass_snapshot() -> Dictionary:
	return _position_smoothing_bypass_by_vcam.duplicate(true)

func get_soft_zone_dead_zone_state(vcam_id: StringName) -> Dictionary:
	var state_variant: Variant = _soft_zone_dead_zone_state.get(vcam_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {
		"x": false,
		"y": false,
	}

func _get_or_create_look_ahead_state(
	vcam_id: StringName,
	follow_target_id: int,
	current_position: Vector3
) -> Dictionary:
	var state_variant: Variant = _look_ahead_state.get(vcam_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = (state_variant as Dictionary).duplicate(true)

	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if state.is_empty() or previous_target_id != follow_target_id:
		state = {
			"follow_target_id": follow_target_id,
			"last_target_position": current_position,
			"current_offset": Vector3.ZERO,
			"smoothing_hz": -1.0,
			"dynamics": null,
		}
		_look_ahead_state[vcam_id] = state
	return state

func _get_or_create_ground_relative_state(
	vcam_id: StringName,
	follow_target_id: int,
	follow_y: float
) -> Dictionary:
	var state_variant: Variant = _ground_relative_state.get(vcam_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = (state_variant as Dictionary).duplicate(true)

	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if state.is_empty() or previous_target_id != follow_target_id:
		state = {
			"initialized": false,
			"follow_target_id": follow_target_id,
			"ground_anchor_y": follow_y,
			"ground_anchor_target_y": follow_y,
			"follow_anchor_y_offset": 0.0,
			"last_ground_reference_y": follow_y,
			"was_grounded": false,
			"blend_hz": -1.0,
			"dynamics": null,
		}
		_ground_relative_state[vcam_id] = state
	return state

func _should_bypass_orbit_position_smoothing(
	mode_script: Script,
	orbit_mode_script: Script,
	has_active_look_input: bool,
	follow_target_speed_mps: float,
	enable_speed: float,
	disable_speed: float,
	was_bypassing: bool
) -> bool:
	if mode_script != orbit_mode_script:
		return false
	if not has_active_look_input:
		return false
	if was_bypassing:
		return follow_target_speed_mps <= disable_speed
	return follow_target_speed_mps <= enable_speed

func _call_apply_position_offset(apply_position_offset: Callable, result: Dictionary, offset: Vector3) -> Dictionary:
	if not apply_position_offset.is_valid():
		return result
	var offset_result_variant: Variant = apply_position_offset.call(result, offset)
	if offset_result_variant is Dictionary:
		return (offset_result_variant as Dictionary).duplicate(true)
	return result

func _call_debug_look_ahead_motion(
	debug_log_motion_state: Callable,
	vcam_id: StringName,
	is_moving: bool,
	follow_target: Node3D,
	movement_velocity: Vector3,
	desired_offset: Vector3
) -> void:
	if not debug_log_motion_state.is_valid():
		return
	debug_log_motion_state.call(vcam_id, is_moving, follow_target, movement_velocity, desired_offset)

func _call_debug_soft_zone_status(
	debug_log_soft_zone_status: Callable,
	vcam_id: StringName,
	status: String,
	correction: Vector3
) -> void:
	if not debug_log_soft_zone_status.is_valid():
		return
	debug_log_soft_zone_status.call(vcam_id, status, correction)

func _call_debug_soft_zone_metrics(
	debug_log_soft_zone_metrics: Callable,
	vcam_id: StringName,
	correction_result: Dictionary,
	correction: Vector3
) -> void:
	if not debug_log_soft_zone_metrics.is_valid():
		return
	debug_log_soft_zone_metrics.call(vcam_id, correction_result, correction)
