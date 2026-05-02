extends RefCounted
class_name U_VCamSoftZoneApplier

## Applies soft zone camera correction for orbit cameras.
## Uses U_VCamSoftZone to compute camera correction vectors that keep
## the follow target within configured screen-space bounds.

const U_VCAM_SOFT_ZONE := preload("res://scripts/core/managers/helpers/u_vcam_soft_zone.gd")
const U_VCAM_UTILS := preload("res://scripts/core/utils/display/u_vcam_utils.gd")

var _soft_zone_dead_zone_state: Dictionary = {}  # StringName -> {x: bool, y: bool}


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
	return U_VCAM_UTILS.call_apply_position_offset(apply_position_offset, result, correction)


func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _soft_zone_dead_zone_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_soft_zone_dead_zone_state.erase(vcam_id)


func clear_all() -> void:
	_soft_zone_dead_zone_state.clear()


func clear_soft_zone_dead_zone_state_for_vcam(vcam_id: StringName) -> void:
	_soft_zone_dead_zone_state.erase(vcam_id)


func get_soft_zone_dead_zone_state_snapshot() -> Dictionary:
	return _soft_zone_dead_zone_state.duplicate(true)


func get_soft_zone_dead_zone_state(vcam_id: StringName) -> Dictionary:
	var state_variant: Variant = _soft_zone_dead_zone_state.get(vcam_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {
		"x": false,
		"y": false,
	}




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