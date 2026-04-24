extends RefCounted
class_name U_VCamLookAhead

## Applies orbit look-ahead offset based on follow-target movement velocity.
## Smoothed via 2nd-order dynamics to prevent jittering.

const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/core/utils/math/u_second_order_dynamics_3d.gd")
const U_VCAM_UTILS := preload("res://scripts/core/utils/display/u_vcam_utils.gd")

const LOOK_AHEAD_MOVEMENT_EPSILON_SQ: float = 0.000001

var _look_ahead_state: Dictionary = {}  # StringName -> {follow_target_id, last_target_position, current_offset, smoothing_hz, dynamics}


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
	return U_VCAM_UTILS.call_apply_position_offset(apply_position_offset, result, smoothed_offset)


func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _look_ahead_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_look_ahead_state.erase(vcam_id)


func clear_all() -> void:
	_look_ahead_state.clear()


func clear_look_ahead_state_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_state.erase(vcam_id)


func get_look_ahead_state_snapshot() -> Dictionary:
	return _look_ahead_state.duplicate(true)


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