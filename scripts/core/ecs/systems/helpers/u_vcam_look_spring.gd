extends RefCounted
class_name U_VCamLookSpring

## 2nd-order spring dynamics for camera look rotation, plus release damping
## and debug stage logging. Provides smoothed rotation values that converge
## toward the target with configurable frequency and damping.

const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_VCAM_UTILS := preload("res://scripts/utils/display/u_vcam_utils.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

const DEFAULT_LOOK_RELEASE_YAW_DAMPING: float = 10.0
const DEFAULT_LOOK_RELEASE_PITCH_DAMPING: float = 12.0
const DEFAULT_LOOK_RELEASE_STOP_THRESHOLD: float = 0.05
const ORBIT_RELEASE_SIGN_FLIP_SETTLE_ERROR_DEG: float = 0.25

var debug_enabled: bool = false
var _look_rotation_state: Dictionary = {}  # StringName -> {smoothed_yaw, smoothed_pitch, yaw_velocity, pitch_velocity, mode_script, follow_target_id, response_signature, input_active}
var _debug_last_look_spring_stage_by_vcam: Dictionary = {}  # StringName -> String
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()


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
	if component == null or mode == null:
		return Vector2.ZERO

	var target_rotation := Vector2(component.runtime_yaw, component.runtime_pitch)
	var mode_script := mode.get_script() as Script
	if mode_script != orbit_mode_script:
		_clear_look_rotation_state_for_vcam(vcam_id)
		return target_rotation
	if response_values.is_empty():
		_clear_look_rotation_state_for_vcam(vcam_id)
		return target_rotation

	var rotation_frequency: float = maxf(float(response_values.get("rotation_frequency", 0.0)), 0.0)
	if rotation_frequency <= 0.0:
		_clear_look_rotation_state_for_vcam(vcam_id)
		return target_rotation
	var rotation_damping: float = maxf(float(response_values.get("rotation_damping", 0.0)), 0.0)
	var follow_target_id: int = U_VCAM_UTILS.get_node_instance_id(follow_target)

	var state: Dictionary = _get_look_rotation_state(vcam_id)
	if (
		state.is_empty()
		or _did_mode_change(state, mode_script)
		or _did_follow_target_change(state, follow_target_id)
		or _did_response_change(state, response_signature)
	):
		_set_look_rotation_state(
			vcam_id,
			target_rotation,
			Vector2.ZERO,
			mode_script,
			follow_target_id,
			response_signature,
			has_active_look_input
		)
		_debug_log_look_spring_stage_transition(
			vcam_id,
			"reseed",
			has_active_look_input
		)
		return target_rotation

	var smoothed_rotation: Vector2 = Vector2(
		float(state.get("smoothed_yaw", target_rotation.x)),
		float(state.get("smoothed_pitch", target_rotation.y))
	)
	var rotation_velocity: Vector2 = Vector2(
		float(state.get("yaw_velocity", 0.0)),
		float(state.get("pitch_velocity", 0.0))
	)
	if delta <= 0.0:
		return smoothed_rotation

	var step_dt: float = minf(maxf(delta, 0.0), U_SECOND_ORDER_DYNAMICS.MAX_STEP_DELTA_SEC)
	if not has_active_look_input:
		var release_yaw_damping: float = maxf(
			float(response_values.get("look_release_yaw_damping", DEFAULT_LOOK_RELEASE_YAW_DAMPING)),
			0.0
		)
		var release_pitch_damping: float = maxf(
			float(response_values.get("look_release_pitch_damping", DEFAULT_LOOK_RELEASE_PITCH_DAMPING)),
			0.0
		)
		var release_stop_threshold: float = maxf(
			float(response_values.get("look_release_stop_threshold", DEFAULT_LOOK_RELEASE_STOP_THRESHOLD)),
			0.0
		)
		var yaw_release_step: Dictionary = _step_orbit_release_axis(
			smoothed_rotation.x,
			target_rotation.x,
			rotation_velocity.x,
			rotation_frequency,
			rotation_damping,
			release_yaw_damping,
			release_stop_threshold,
			step_dt
		)
		var pitch_release_step: Dictionary = _step_orbit_release_axis(
			smoothed_rotation.y,
			target_rotation.y,
			rotation_velocity.y,
			rotation_frequency,
			rotation_damping,
			release_pitch_damping,
			release_stop_threshold,
			step_dt
		)
		smoothed_rotation = Vector2(
			float(yaw_release_step.get("value", target_rotation.x)),
			float(pitch_release_step.get("value", target_rotation.y))
		)
		rotation_velocity = Vector2(
			float(yaw_release_step.get("velocity", 0.0)),
			float(pitch_release_step.get("velocity", 0.0))
		)
		_set_look_rotation_state(
			vcam_id,
			smoothed_rotation,
			rotation_velocity,
			mode_script,
			follow_target_id,
			response_signature,
			has_active_look_input
		)
		_debug_log_look_spring_stage_transition(
			vcam_id,
			"orbit_release",
			has_active_look_input
		)
		return smoothed_rotation

	var yaw_step: Dictionary = _step_second_order_angle(
		smoothed_rotation.x,
		target_rotation.x,
		rotation_velocity.x,
		rotation_frequency,
		rotation_damping,
		step_dt
	)
	var pitch_step: Dictionary = _step_second_order_angle(
		smoothed_rotation.y,
		target_rotation.y,
		rotation_velocity.y,
		rotation_frequency,
		rotation_damping,
		step_dt
	)
	smoothed_rotation = Vector2(
		float(yaw_step.get("value", target_rotation.x)),
		float(pitch_step.get("value", target_rotation.y))
	)
	rotation_velocity = Vector2(
		float(yaw_step.get("velocity", 0.0)),
		float(pitch_step.get("velocity", 0.0))
	)
	_set_look_rotation_state(
		vcam_id,
		smoothed_rotation,
		rotation_velocity,
		mode_script,
		follow_target_id,
		response_signature,
		has_active_look_input
	)
	_debug_log_look_spring_stage_transition(
		vcam_id,
		"step",
		has_active_look_input
	)
	return smoothed_rotation


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
	return _step_orbit_release_axis(
		current_value,
		target_value,
		current_velocity,
		frequency_hz,
		damping_ratio,
		release_damping,
		stop_threshold,
		delta
	)


func clear_rotation_state_for_vcam(vcam_id: StringName) -> void:
	_look_rotation_state.erase(vcam_id)
	_debug_last_look_spring_stage_by_vcam.erase(vcam_id)


func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _look_rotation_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			clear_rotation_state_for_vcam(vcam_id)


func clear_all() -> void:
	_look_rotation_state.clear()
	_debug_last_look_spring_stage_by_vcam.clear()


func get_look_rotation_state_snapshot() -> Dictionary:
	return _look_rotation_state.duplicate(true)


func _step_orbit_release_axis(
	current_value: float,
	target_value: float,
	current_velocity: float,
	frequency_hz: float,
	damping_ratio: float,
	release_damping: float,
	stop_threshold: float,
	delta: float
) -> Dictionary:
	var error_before: float = wrapf(target_value - current_value, -180.0, 180.0)
	var axis_step: Dictionary = _step_second_order_angle(
		current_value,
		target_value,
		current_velocity,
		frequency_hz,
		damping_ratio,
		delta
	)
	var next_value: float = float(axis_step.get("value", target_value))
	var velocity_before_damping: float = float(axis_step.get("velocity", 0.0))
	var next_velocity: float = _apply_release_velocity_damping(
		velocity_before_damping,
		release_damping,
		stop_threshold,
		delta
	)
	if is_equal_approx(next_velocity, 0.0):
		var remaining_error: float = absf(wrapf(target_value - next_value, -180.0, 180.0))
		var settle_epsilon: float = maxf(stop_threshold * maxf(delta, 0.0), 0.0001)
		if remaining_error <= settle_epsilon:
			next_value = target_value
	var error_after: float = wrapf(target_value - next_value, -180.0, 180.0)
	var crossed_target: bool = error_before * error_after < 0.0
	if crossed_target and absf(error_before) <= ORBIT_RELEASE_SIGN_FLIP_SETTLE_ERROR_DEG:
		next_value = target_value
		next_velocity = 0.0

	return {
		"value": next_value,
		"velocity": next_velocity,
	}


func _apply_release_velocity_damping(
	velocity: float,
	damping_per_sec: float,
	stop_threshold: float,
	delta: float
) -> float:
	var next_velocity: float = velocity
	var resolved_damping: float = maxf(damping_per_sec, 0.0)
	var resolved_threshold: float = maxf(stop_threshold, 0.0)
	if resolved_damping > 0.0 and delta > 0.0:
		next_velocity *= exp(-resolved_damping * delta)
	if absf(next_velocity) <= resolved_threshold:
		return 0.0
	return next_velocity


func _step_second_order_angle(
	current_value: float,
	target_value: float,
	current_velocity: float,
	frequency_hz: float,
	damping_ratio: float,
	delta: float
) -> Dictionary:
	var omega: float = TAU * maxf(frequency_hz, 0.0)
	if omega <= 0.0:
		return {
			"value": target_value,
			"velocity": 0.0,
		}

	var error: float = wrapf(target_value - current_value, -180.0, 180.0)
	var accel: float = (omega * omega * error) - (2.0 * damping_ratio * omega * current_velocity)
	var next_velocity: float = current_velocity + accel * delta
	var next_value: float = current_value + next_velocity * delta
	if is_nan(next_value) or is_inf(next_value):
		next_value = target_value
	if is_nan(next_velocity) or is_inf(next_velocity):
		next_velocity = 0.0
	return {
		"value": next_value,
		"velocity": next_velocity,
	}


func _get_look_rotation_state(vcam_id: StringName) -> Dictionary:
	var state_variant: Variant = _look_rotation_state.get(vcam_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {}


func _set_look_rotation_state(
	vcam_id: StringName,
	smoothed_rotation: Vector2,
	rotation_velocity: Vector2,
	mode_script: Script,
	follow_target_id: int,
	response_signature: Array[float],
	input_active: bool
) -> void:
	_look_rotation_state[vcam_id] = {
		"smoothed_yaw": smoothed_rotation.x,
		"smoothed_pitch": smoothed_rotation.y,
		"yaw_velocity": rotation_velocity.x,
		"pitch_velocity": rotation_velocity.y,
		"mode_script": mode_script,
		"follow_target_id": follow_target_id,
		"response_signature": response_signature.duplicate(),
		"input_active": input_active,
	}


func _clear_look_rotation_state_for_vcam(vcam_id: StringName) -> void:
	_look_rotation_state.erase(vcam_id)
	_debug_last_look_spring_stage_by_vcam.erase(vcam_id)


func _did_mode_change(state: Dictionary, mode_script: Script) -> bool:
	var previous_mode_variant: Variant = state.get("mode_script", null)
	if previous_mode_variant == null:
		return mode_script != null
	var previous_mode := previous_mode_variant as Script
	return previous_mode != mode_script


func _did_follow_target_change(state: Dictionary, follow_target_id: int) -> bool:
	return int(state.get("follow_target_id", 0)) != follow_target_id


func _did_response_change(state: Dictionary, response_signature: Array[float]) -> bool:
	var previous_signature_variant: Variant = state.get("response_signature", [])
	if not (previous_signature_variant is Array):
		return true
	var previous_signature := previous_signature_variant as Array
	if previous_signature.size() != response_signature.size():
		return true
	for index in range(response_signature.size()):
		if not is_equal_approx(float(previous_signature[index]), response_signature[index]):
			return true
	return false



func _debug_log_look_spring_stage_transition(
	vcam_id: StringName,
	stage: String,
	has_active_look_input: bool
) -> void:
	if not debug_enabled:
		return
	var previous_stage: String = String(_debug_last_look_spring_stage_by_vcam.get(vcam_id, ""))
	if previous_stage == stage:
		return
	_debug_last_look_spring_stage_by_vcam[vcam_id] = stage
	_debug_log_throttle.log_message(
		"U_VCamLookSpring[debug] look_spring_stage: vcam_id=%s stage=%s prev=%s active_input=%s"
		% [
			String(vcam_id),
			stage,
			previous_stage,
			str(has_active_look_input),
		]
	)
