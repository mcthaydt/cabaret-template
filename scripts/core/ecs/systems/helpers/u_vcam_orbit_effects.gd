extends RefCounted
class_name U_VCamOrbitEffects

## Thin coordinator that delegates to three decomposed helpers:
##   U_VCamLookAhead — orbit look-ahead offset from follow-target velocity
##   U_VCamGroundAnchor — ground-relative vertical anchoring
##   U_VCamSoftZoneApplier — soft zone camera correction
##
## Also owns follow-target speed sampling and position-smoothing bypass state,
## which are consumed by the response smoother via the effect pipeline.

const U_VCAM_LOOK_AHEAD := preload("res://scripts/core/ecs/systems/helpers/u_vcam_look_ahead.gd")
const U_VCAM_GROUND_ANCHOR := preload("res://scripts/core/ecs/systems/helpers/u_vcam_ground_anchor.gd")
const U_VCAM_SOFT_ZONE_APPLIER := preload("res://scripts/core/ecs/systems/helpers/u_vcam_soft_zone_applier.gd")

const DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED: float = 0.15
const DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED: float = 0.3

var _look_ahead_helper := U_VCAM_LOOK_AHEAD.new()
var _ground_anchor_helper := U_VCAM_GROUND_ANCHOR.new()
var _soft_zone_helper := U_VCAM_SOFT_ZONE_APPLIER.new()
var _follow_target_motion_state: Dictionary = {}  # StringName -> {follow_target_id, last_position, speed_mps}
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
	return _look_ahead_helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		orbit_mode_script,
		follow_target,
		result,
		response_values,
		has_active_look_input,
		delta,
		resolve_look_ahead_velocity,
		apply_position_offset,
		debug_log_motion_state
	)

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
	return _ground_anchor_helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		orbit_mode_script,
		follow_target,
		result,
		response_values,
		delta,
		resolve_grounded_state,
		probe_ground_reference_height,
		apply_position_offset
	)

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
	return _soft_zone_helper.apply_orbit_soft_zone(
		vcam_id,
		mode,
		orbit_mode_script,
		follow_target,
		soft_zone,
		soft_zone_script,
		result,
		delta,
		resolve_projection_camera,
		apply_position_offset,
		debug_log_soft_zone_status,
		debug_log_soft_zone_metrics
	)

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
	_look_ahead_helper.prune(active_vcam_ids)
	_ground_anchor_helper.prune(active_vcam_ids)
	_soft_zone_helper.prune(active_vcam_ids)
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _follow_target_motion_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_follow_target_motion_state.erase(vcam_id)
	for vcam_id_variant in _position_smoothing_bypass_by_vcam.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_position_smoothing_bypass_by_vcam.erase(vcam_id)

func clear_all() -> void:
	_look_ahead_helper.clear_all()
	_ground_anchor_helper.clear_all()
	_soft_zone_helper.clear_all()
	_follow_target_motion_state.clear()
	_position_smoothing_bypass_by_vcam.clear()

func clear_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_helper.clear_look_ahead_state_for_vcam(vcam_id)
	_ground_anchor_helper.clear_ground_relative_state_for_vcam(vcam_id)
	_soft_zone_helper.clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
	_follow_target_motion_state.erase(vcam_id)
	_position_smoothing_bypass_by_vcam.erase(vcam_id)

func clear_look_ahead_state_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_helper.clear_look_ahead_state_for_vcam(vcam_id)

func clear_ground_relative_state_for_vcam(vcam_id: StringName) -> void:
	_ground_anchor_helper.clear_ground_relative_state_for_vcam(vcam_id)

func clear_soft_zone_dead_zone_state_for_vcam(vcam_id: StringName) -> void:
	_soft_zone_helper.clear_soft_zone_dead_zone_state_for_vcam(vcam_id)

func get_look_ahead_state_snapshot() -> Dictionary:
	return _look_ahead_helper.get_look_ahead_state_snapshot()

func get_ground_relative_state_snapshot() -> Dictionary:
	return _ground_anchor_helper.get_ground_relative_state_snapshot()

func get_follow_target_motion_state_snapshot() -> Dictionary:
	return _follow_target_motion_state.duplicate(true)

func get_soft_zone_dead_zone_state_snapshot() -> Dictionary:
	return _soft_zone_helper.get_soft_zone_dead_zone_state_snapshot()

func get_position_smoothing_bypass_snapshot() -> Dictionary:
	return _position_smoothing_bypass_by_vcam.duplicate(true)

func get_soft_zone_dead_zone_state(vcam_id: StringName) -> Dictionary:
	return _soft_zone_helper.get_soft_zone_dead_zone_state(vcam_id)

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