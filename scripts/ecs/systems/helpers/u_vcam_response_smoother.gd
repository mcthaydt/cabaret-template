extends RefCounted
class_name U_VCamResponseSmoother

const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/utils/math/u_second_order_dynamics_3d.gd")

var _follow_dynamics: Dictionary = {}  # StringName -> U_SecondOrderDynamics3D
var _rotation_dynamics: Dictionary = {}  # StringName -> {x, y, z}
var _smoothing_metadata: Dictionary = {}  # StringName -> {mode_script, follow_target_id, response_signature}
var _rotation_target_cache: Dictionary = {}  # StringName -> Vector3 (unwrapped radians)

func apply_response_smoothing(
	vcam_id: StringName,
	mode_script: Script,
	orbit_mode_script: Script,
	follow_target_id: int,
	follow_target_speed_mps: float,
	raw_result: Dictionary,
	delta: float,
	has_active_look_input: bool,
	response_values: Dictionary,
	response_signature: Array[float],
	update_orbit_bypass: Callable,
	default_orbit_look_bypass_enable_speed: float,
	default_orbit_look_bypass_disable_speed: float,
	debug_log_position_smoothing_gate_transition: Callable = Callable(),
	debug_log_rotation: Callable = Callable()
) -> Dictionary:
	var raw_transform_variant: Variant = raw_result.get("transform", null)
	if not (raw_transform_variant is Transform3D):
		return raw_result
	if response_values.is_empty():
		clear_for_vcam(vcam_id)
		return raw_result

	var raw_transform := raw_transform_variant as Transform3D
	var raw_euler: Vector3 = raw_transform.basis.get_euler()
	var target_euler: Vector3 = _resolve_unwrapped_target_euler(vcam_id, raw_euler)
	var metadata: Dictionary = _get_smoothing_metadata(vcam_id)
	var has_state: bool = _follow_dynamics.has(vcam_id) and _rotation_dynamics.has(vcam_id)
	var response_changed: bool = _did_response_change(metadata, response_signature)

	if not has_state or response_changed:
		_create_smoothing_state(vcam_id, response_values, raw_transform.origin, target_euler)
		_set_smoothing_metadata(vcam_id, mode_script, follow_target_id, response_signature)
		return raw_result

	var mode_changed: bool = _did_mode_change(metadata, mode_script)
	var target_changed: bool = _did_follow_target_change(metadata, follow_target_id)
	if mode_changed or target_changed:
		_reset_smoothing_state(vcam_id, raw_transform.origin, target_euler)
		_set_smoothing_metadata(vcam_id, mode_script, follow_target_id, response_signature)
		return raw_result

	_set_smoothing_metadata(vcam_id, mode_script, follow_target_id, response_signature)
	return _step_smoothing_state(
		vcam_id,
		raw_result,
		raw_transform,
		mode_script,
		orbit_mode_script,
		delta,
		has_active_look_input,
		response_values,
		follow_target_speed_mps,
		update_orbit_bypass,
		default_orbit_look_bypass_enable_speed,
		default_orbit_look_bypass_disable_speed,
		debug_log_position_smoothing_gate_transition,
		debug_log_rotation
	)

func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id == StringName(""):
			continue
		keep_ids[keep_id] = true

	var stale_ids: Array[StringName] = []
	for vcam_id_variant in _follow_dynamics.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _rotation_dynamics.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _smoothing_metadata.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _rotation_target_cache.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		clear_for_vcam(stale_id)

func clear_all() -> void:
	_follow_dynamics.clear()
	_rotation_dynamics.clear()
	_smoothing_metadata.clear()
	_rotation_target_cache.clear()

func clear_for_vcam(vcam_id: StringName) -> void:
	_follow_dynamics.erase(vcam_id)
	_rotation_dynamics.erase(vcam_id)
	_smoothing_metadata.erase(vcam_id)
	_rotation_target_cache.erase(vcam_id)

func get_follow_dynamics_snapshot() -> Dictionary:
	return _follow_dynamics.duplicate(true)

func get_rotation_dynamics_snapshot() -> Dictionary:
	return _rotation_dynamics.duplicate(true)

func get_smoothing_metadata_snapshot() -> Dictionary:
	return _smoothing_metadata.duplicate(true)

func get_rotation_target_cache_snapshot() -> Dictionary:
	return _rotation_target_cache.duplicate(true)

func _step_smoothing_state(
	vcam_id: StringName,
	raw_result: Dictionary,
	raw_transform: Transform3D,
	mode_script: Script,
	orbit_mode_script: Script,
	delta: float,
	has_active_look_input: bool,
	response_values: Dictionary,
	follow_target_speed_mps: float,
	update_orbit_bypass: Callable,
	default_orbit_look_bypass_enable_speed: float,
	default_orbit_look_bypass_disable_speed: float,
	debug_log_position_smoothing_gate_transition: Callable,
	debug_log_rotation: Callable
) -> Dictionary:
	var follow_dynamics: Variant = _follow_dynamics.get(vcam_id, null)
	if follow_dynamics == null:
		return raw_result

	var bypass_state: Dictionary = {}
	if update_orbit_bypass.is_valid():
		var bypass_variant: Variant = update_orbit_bypass.call(
			vcam_id,
			mode_script,
			orbit_mode_script,
			has_active_look_input,
			follow_target_speed_mps,
			response_values,
			default_orbit_look_bypass_enable_speed,
			default_orbit_look_bypass_disable_speed
		)
		if bypass_variant is Dictionary:
			bypass_state = (bypass_variant as Dictionary).duplicate(true)

	var bypass_non_fixed_position_smoothing: bool = bool(bypass_state.get("bypass", false))
	var bypass_enable_speed: float = float(
		bypass_state.get("enable_speed", default_orbit_look_bypass_enable_speed)
	)
	var bypass_disable_speed: float = float(
		bypass_state.get("disable_speed", default_orbit_look_bypass_disable_speed)
	)
	var has_previous_bypass_state: bool = bool(
		bypass_state.get("had_previous_bypass_state", false)
	)
	var previous_bypass: bool = bool(bypass_state.get("previous_bypass", false))
	if previous_bypass != bypass_non_fixed_position_smoothing:
		if debug_log_position_smoothing_gate_transition.is_valid():
			debug_log_position_smoothing_gate_transition.call(
				vcam_id,
				mode_script,
				has_active_look_input,
				raw_transform.origin,
				follow_dynamics,
				follow_target_speed_mps,
				bypass_enable_speed,
				bypass_disable_speed,
				previous_bypass,
				bypass_non_fixed_position_smoothing
			)

	var released_orbit_bypass_this_tick: bool = (
		has_previous_bypass_state
		and previous_bypass
		and not bypass_non_fixed_position_smoothing
		and mode_script == orbit_mode_script
	)
	if released_orbit_bypass_this_tick:
		follow_dynamics.reset(raw_transform.origin)
		if debug_log_rotation.is_valid():
			debug_log_rotation.call(
				vcam_id,
				"smoothing_gate_handoff: orbit bypass released, resetting follow dynamics to raw position"
			)
		return raw_result

	if bypass_non_fixed_position_smoothing:
		follow_dynamics.reset(raw_transform.origin)
		return raw_result

	var smooth_position: Vector3 = follow_dynamics.step(raw_transform.origin, delta)
	var smooth_transform := Transform3D(raw_transform.basis.orthonormalized(), smooth_position)
	var smoothed_result: Dictionary = raw_result.duplicate(true)
	smoothed_result["transform"] = smooth_transform
	return smoothed_result

func _create_smoothing_state(
	vcam_id: StringName,
	response_values: Dictionary,
	initial_position: Vector3,
	initial_euler: Vector3
) -> void:
	var follow_frequency: float = float(response_values.get("follow_frequency", 3.0))
	var follow_damping: float = float(response_values.get("follow_damping", 0.7))
	var follow_response: float = float(response_values.get("follow_initial_response", 1.0))
	var rotation_frequency: float = float(response_values.get("rotation_frequency", 4.0))
	var rotation_damping: float = float(response_values.get("rotation_damping", 1.0))
	var rotation_response: float = float(response_values.get("rotation_initial_response", 1.0))

	_follow_dynamics[vcam_id] = U_SECOND_ORDER_DYNAMICS_3D.new(
		follow_frequency,
		follow_damping,
		follow_response,
		initial_position
	)
	_rotation_dynamics[vcam_id] = {
		"x": U_SECOND_ORDER_DYNAMICS.new(rotation_frequency, rotation_damping, rotation_response, initial_euler.x),
		"y": U_SECOND_ORDER_DYNAMICS.new(rotation_frequency, rotation_damping, rotation_response, initial_euler.y),
		"z": U_SECOND_ORDER_DYNAMICS.new(rotation_frequency, rotation_damping, rotation_response, initial_euler.z),
	}
	_rotation_target_cache[vcam_id] = initial_euler

func _reset_smoothing_state(vcam_id: StringName, position: Vector3, euler: Vector3) -> void:
	var follow_dynamics: Variant = _follow_dynamics.get(vcam_id, null)
	if follow_dynamics != null:
		follow_dynamics.reset(position)

	var rotation_entry_variant: Variant = _rotation_dynamics.get(vcam_id, {})
	if rotation_entry_variant is Dictionary:
		var rotation_entry := rotation_entry_variant as Dictionary
		_reset_rotation_axis(rotation_entry, StringName("x"), euler.x)
		_reset_rotation_axis(rotation_entry, StringName("y"), euler.y)
		_reset_rotation_axis(rotation_entry, StringName("z"), euler.z)

	_rotation_target_cache[vcam_id] = euler

func _reset_rotation_axis(rotation_entry: Dictionary, key: StringName, value: float) -> void:
	var axis_dynamics: Variant = rotation_entry.get(key, null)
	if axis_dynamics == null:
		return
	axis_dynamics.reset(value)

func _get_smoothing_metadata(vcam_id: StringName) -> Dictionary:
	var metadata_variant: Variant = _smoothing_metadata.get(vcam_id, {})
	if metadata_variant is Dictionary:
		return (metadata_variant as Dictionary).duplicate(true)
	return {}

func _set_smoothing_metadata(
	vcam_id: StringName,
	mode_script: Script,
	follow_target_id: int,
	response_signature: Array[float]
) -> void:
	_smoothing_metadata[vcam_id] = {
		"mode_script": mode_script,
		"follow_target_id": follow_target_id,
		"response_signature": response_signature.duplicate(),
	}

func _did_mode_change(metadata: Dictionary, mode_script: Script) -> bool:
	if metadata.is_empty():
		return false
	var previous_mode_variant: Variant = metadata.get("mode_script", null)
	if previous_mode_variant == null:
		return mode_script != null
	var previous_mode := previous_mode_variant as Script
	return previous_mode != mode_script

func _did_follow_target_change(metadata: Dictionary, follow_target_id: int) -> bool:
	if metadata.is_empty():
		return false
	var previous_target_id: int = int(metadata.get("follow_target_id", 0))
	return previous_target_id != follow_target_id

func _did_response_change(metadata: Dictionary, response_signature: Array[float]) -> bool:
	if metadata.is_empty():
		return false
	var previous_signature_variant: Variant = metadata.get("response_signature", [])
	if not (previous_signature_variant is Array):
		return true
	var previous_signature := previous_signature_variant as Array
	if previous_signature.size() != response_signature.size():
		return true
	for index in range(response_signature.size()):
		if not is_equal_approx(float(previous_signature[index]), response_signature[index]):
			return true
	return false

func _resolve_unwrapped_target_euler(vcam_id: StringName, target_euler: Vector3) -> Vector3:
	if not _rotation_target_cache.has(vcam_id):
		_rotation_target_cache[vcam_id] = target_euler
		return target_euler

	var previous_target := _rotation_target_cache.get(vcam_id, target_euler) as Vector3
	var unwrapped_target := Vector3(
		_unwrap_angle_to_reference(target_euler.x, previous_target.x),
		_unwrap_angle_to_reference(target_euler.y, previous_target.y),
		_unwrap_angle_to_reference(target_euler.z, previous_target.z)
	)
	_rotation_target_cache[vcam_id] = unwrapped_target
	return unwrapped_target

func _unwrap_angle_to_reference(target_angle: float, reference_angle: float) -> float:
	return reference_angle + wrapf(target_angle - reference_angle, -PI, PI)
