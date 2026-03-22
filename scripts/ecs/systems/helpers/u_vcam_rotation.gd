extends RefCounted
class_name U_VCamRotation

const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")

const IDLE_LOOK_SETTLE_DEG_PER_HZ: float = 20.0
const MIN_IDLE_LOOK_SETTLE_DEG_PER_SEC: float = 45.0
const DEFAULT_LOOK_RELEASE_YAW_DAMPING: float = 10.0
const DEFAULT_LOOK_RELEASE_PITCH_DAMPING: float = 12.0
const DEFAULT_LOOK_RELEASE_STOP_THRESHOLD: float = 0.05
const ORBIT_RELEASE_SIGN_FLIP_SETTLE_ERROR_DEG: float = 0.25
const ORBIT_CENTER_DURATION_SEC: float = 0.3

var debug_enabled: bool = false
var _look_rotation_state: Dictionary = {}  # StringName -> {smoothed_yaw, smoothed_pitch, yaw_velocity, pitch_velocity, mode_script, follow_target_id, response_signature, input_active}
var _orbit_no_look_input_timers: Dictionary = {}  # StringName -> float seconds
var _orbit_centering_state: Dictionary = {}  # StringName -> {start_yaw,start_pitch,target_yaw,target_pitch,elapsed_sec,duration_sec}
var _debug_last_look_spring_stage_by_vcam: Dictionary = {}  # StringName -> String

func apply_rotation_continuity_policy(
	active_vcam_id: StringName,
	vcam_index: Dictionary,
	previous_vcam_id: StringName,
	last_active_vcam_id: StringName,
	resolve_follow_target: Callable,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> StringName:
	if last_active_vcam_id == active_vcam_id:
		return last_active_vcam_id

	var incoming_component: Object = _resolve_live_component(vcam_index, active_vcam_id)
	if incoming_component == null:
		return active_vcam_id

	var outgoing_vcam_id: StringName = previous_vcam_id
	if outgoing_vcam_id == StringName("") or outgoing_vcam_id == active_vcam_id:
		outgoing_vcam_id = last_active_vcam_id
	if outgoing_vcam_id == StringName("") or outgoing_vcam_id == active_vcam_id:
		return active_vcam_id

	var outgoing_component: Object = _resolve_live_component(vcam_index, outgoing_vcam_id)
	if outgoing_component == null:
		return active_vcam_id

	_apply_rotation_transition(
		outgoing_component,
		incoming_component,
		resolve_follow_target,
		resolve_mode_values,
		orbit_mode_script
	)
	return active_vcam_id

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
		_orbit_centering_state.erase(vcam_id)
		return

	var orbit_values: Dictionary = _resolve_orbit_mode_values(mode, resolve_mode_values)
	if not bool(orbit_values.get("allow_player_rotation", true)):
		_orbit_no_look_input_timers.erase(vcam_id)
		_orbit_centering_state.erase(vcam_id)
		return

	var lock_x_rotation: bool = bool(orbit_values.get("lock_x_rotation", false))
	var lock_y_rotation: bool = bool(orbit_values.get("lock_y_rotation", true))
	if lock_x_rotation:
		component.runtime_yaw = 0.0
		_orbit_centering_state.erase(vcam_id)
	if lock_y_rotation:
		component.runtime_pitch = 0.0

	if camera_center_just_pressed and not lock_x_rotation:
		_start_orbit_centering(vcam_id, component, mode, follow_target, resolve_mode_values, orbit_mode_script)
	if _step_orbit_centering(vcam_id, component, delta):
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
	var follow_target_id: int = _get_node_instance_id(follow_target)

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

func resolve_orbit_center_target_yaw(
	mode: Resource,
	follow_target: Node3D,
	current_runtime_yaw: float,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> float:
	return _resolve_orbit_center_target_yaw(
		mode,
		follow_target,
		current_runtime_yaw,
		resolve_mode_values,
		orbit_mode_script
	)

func is_orbit_centering_active(vcam_id: StringName) -> bool:
	var state_variant: Variant = _orbit_centering_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		return false
	return not (state_variant as Dictionary).is_empty()

func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id == StringName(""):
			continue
		keep_ids[keep_id] = true

	var stale_ids: Array[StringName] = []
	for vcam_id_variant in _look_rotation_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _orbit_no_look_input_timers.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _orbit_centering_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id) or stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		clear_for_vcam(stale_id)

func clear_all() -> void:
	_look_rotation_state.clear()
	_orbit_no_look_input_timers.clear()
	_orbit_centering_state.clear()
	_debug_last_look_spring_stage_by_vcam.clear()

func clear_rotation_state_for_vcam(vcam_id: StringName) -> void:
	_look_rotation_state.erase(vcam_id)
	_orbit_no_look_input_timers.erase(vcam_id)
	_debug_last_look_spring_stage_by_vcam.erase(vcam_id)

func clear_centering_state_for_vcam(vcam_id: StringName) -> void:
	_orbit_centering_state.erase(vcam_id)

func clear_for_vcam(vcam_id: StringName) -> void:
	clear_rotation_state_for_vcam(vcam_id)
	clear_centering_state_for_vcam(vcam_id)

func get_look_rotation_state_snapshot() -> Dictionary:
	return _look_rotation_state.duplicate(true)

func get_orbit_centering_state_snapshot() -> Dictionary:
	return _orbit_centering_state.duplicate(true)

func get_orbit_no_look_input_timers_snapshot() -> Dictionary:
	return _orbit_no_look_input_timers.duplicate(true)

func _resolve_live_component(vcam_index: Dictionary, vcam_id: StringName) -> Object:
	var component_variant: Variant = vcam_index.get(vcam_id, null)
	if typeof(component_variant) != TYPE_OBJECT:
		return null
	if component_variant == null:
		return null
	if not is_instance_valid(component_variant):
		return null
	return component_variant as Object

func _apply_rotation_transition(
	outgoing_component: Object,
	incoming_component: Object,
	resolve_follow_target: Callable,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> void:
	if outgoing_component == null or incoming_component == null:
		return
	var outgoing_mode: Resource = outgoing_component.mode as Resource
	var incoming_mode: Resource = incoming_component.mode as Resource
	if outgoing_mode == null or incoming_mode == null:
		return
	var outgoing_mode_script := outgoing_mode.get_script() as Script
	var incoming_mode_script := incoming_mode.get_script() as Script
	if outgoing_mode_script == null or incoming_mode_script == null:
		return
	if outgoing_mode_script != incoming_mode_script:
		return

	if _components_share_follow_target(outgoing_component, incoming_component, resolve_follow_target):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = outgoing_component.runtime_pitch
		return

	var authored_angles: Vector2 = _resolve_authored_rotation(incoming_mode, resolve_mode_values, orbit_mode_script)
	incoming_component.runtime_yaw = authored_angles.x
	incoming_component.runtime_pitch = authored_angles.y

func _components_share_follow_target(
	outgoing_component: Object,
	incoming_component: Object,
	resolve_follow_target: Callable
) -> bool:
	if not resolve_follow_target.is_valid():
		return false
	var outgoing_target_variant: Variant = resolve_follow_target.call(outgoing_component)
	var incoming_target_variant: Variant = resolve_follow_target.call(incoming_component)
	if not (outgoing_target_variant is Node3D) or not (incoming_target_variant is Node3D):
		return false
	var outgoing_target := outgoing_target_variant as Node3D
	var incoming_target := incoming_target_variant as Node3D
	if outgoing_target == null or incoming_target == null:
		return false
	if not is_instance_valid(outgoing_target) or not is_instance_valid(incoming_target):
		return false
	return _get_node_instance_id(outgoing_target) == _get_node_instance_id(incoming_target)

func _resolve_authored_rotation(mode: Resource, resolve_mode_values: Callable, orbit_mode_script: Script) -> Vector2:
	if mode == null:
		return Vector2.ZERO
	if mode.get_script() != orbit_mode_script:
		return Vector2.ZERO
	if not resolve_mode_values.is_valid():
		return Vector2.ZERO
	var orbit_values_variant: Variant = resolve_mode_values.call(mode, {
		"authored_yaw": 0.0,
		"authored_pitch": 0.0,
	})
	if not (orbit_values_variant is Dictionary):
		return Vector2.ZERO
	var orbit_values := orbit_values_variant as Dictionary
	return Vector2(
		float(orbit_values.get("authored_yaw", 0.0)),
		float(orbit_values.get("authored_pitch", 0.0))
	)

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

func _start_orbit_centering(
	vcam_id: StringName,
	component: Object,
	mode: Resource,
	follow_target: Node3D,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> void:
	if component == null or mode == null:
		return

	var start_yaw: float = component.runtime_yaw
	var start_pitch: float = component.runtime_pitch
	var target_yaw: float = _resolve_orbit_center_target_yaw(
		mode,
		follow_target,
		start_yaw,
		resolve_mode_values,
		orbit_mode_script
	)
	_orbit_centering_state[vcam_id] = {
		"start_yaw": start_yaw,
		"start_pitch": start_pitch,
		"target_yaw": target_yaw,
		"target_pitch": start_pitch,
		"elapsed_sec": 0.0,
		"duration_sec": ORBIT_CENTER_DURATION_SEC,
	}

func _step_orbit_centering(vcam_id: StringName, component: Object, delta: float) -> bool:
	if component == null:
		return false
	var state_variant: Variant = _orbit_centering_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		return false
	var state := state_variant as Dictionary
	if state.is_empty():
		return false

	var start_yaw: float = float(state.get("start_yaw", component.runtime_yaw))
	var start_pitch: float = float(state.get("start_pitch", component.runtime_pitch))
	var target_yaw: float = float(state.get("target_yaw", start_yaw))
	var target_pitch: float = float(state.get("target_pitch", start_pitch))
	var duration_sec: float = maxf(float(state.get("duration_sec", ORBIT_CENTER_DURATION_SEC)), 0.0001)
	var elapsed_sec: float = float(state.get("elapsed_sec", 0.0))
	if delta > 0.0:
		elapsed_sec += delta
	state["elapsed_sec"] = elapsed_sec
	_orbit_centering_state[vcam_id] = state

	var raw_t: float = clampf(elapsed_sec / duration_sec, 0.0, 1.0)
	var smooth_t: float = raw_t * raw_t * (3.0 - (2.0 * raw_t))
	var yaw_delta: float = wrapf(target_yaw - start_yaw, -180.0, 180.0)
	component.runtime_yaw = start_yaw + (yaw_delta * smooth_t)
	component.runtime_pitch = lerpf(start_pitch, target_pitch, smooth_t)

	if raw_t >= 1.0:
		component.runtime_yaw = start_yaw + yaw_delta
		component.runtime_pitch = target_pitch
		_orbit_centering_state.erase(vcam_id)
	return true

func _resolve_orbit_center_target_yaw(
	mode: Resource,
	follow_target: Node3D,
	current_runtime_yaw: float,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> float:
	if mode == null:
		return current_runtime_yaw

	var authored_yaw: float = 0.0
	if mode.get_script() == orbit_mode_script and resolve_mode_values.is_valid():
		var orbit_values_variant: Variant = resolve_mode_values.call(mode, {"authored_yaw": 0.0})
		if orbit_values_variant is Dictionary:
			authored_yaw = float((orbit_values_variant as Dictionary).get("authored_yaw", 0.0))

	if follow_target == null or not is_instance_valid(follow_target):
		return current_runtime_yaw

	var behind_direction: Vector3 = follow_target.global_transform.basis.z
	var planar_length_sq: float = (behind_direction.x * behind_direction.x) + (behind_direction.z * behind_direction.z)
	if planar_length_sq <= 0.000001:
		return current_runtime_yaw

	var target_total_yaw: float = rad_to_deg(atan2(behind_direction.x, behind_direction.z))
	var target_runtime_yaw: float = target_total_yaw - authored_yaw
	return current_runtime_yaw + wrapf(target_runtime_yaw - current_runtime_yaw, -180.0, 180.0)

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

func _get_node_instance_id(node: Node) -> int:
	if node == null:
		return 0
	if not is_instance_valid(node):
		return 0
	return node.get_instance_id()

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
	print(
		"U_VCamRotation[debug] look_spring_stage: vcam_id=%s stage=%s prev=%s active_input=%s"
		% [
			String(vcam_id),
			stage,
			previous_stage,
			str(has_active_look_input),
		]
	)
