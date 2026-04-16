extends RefCounted
class_name U_VCamGroundAnchor

## Applies ground-relative vertical anchoring for orbit cameras.
## Uses 2nd-order dynamics to blend between ground reference heights,
## re-anchoring on landing and smoothly following ground height changes.

const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_VCAM_UTILS := preload("res://scripts/utils/display/u_vcam_utils.gd")

var _ground_relative_state: Dictionary = {}  # StringName -> {initialized, follow_target_id, ground_anchor_y, ...}


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
	return U_VCAM_UTILS.call_apply_position_offset(apply_position_offset, result, Vector3(0.0, y_offset, 0.0))


func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _ground_relative_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_ground_relative_state.erase(vcam_id)


func clear_all() -> void:
	_ground_relative_state.clear()


func clear_ground_relative_state_for_vcam(vcam_id: StringName) -> void:
	_ground_relative_state.erase(vcam_id)


func get_ground_relative_state_snapshot() -> Dictionary:
	return _ground_relative_state.duplicate(true)


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

