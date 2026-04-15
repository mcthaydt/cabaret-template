extends RefCounted
class_name U_VCamOrbitCentering

## Handles orbit "look behind" centering animation.
## When the player presses the camera-center button, the vCam smoothly
## interpolates back to the authored yaw / behind-the-target orientation.

const ORBIT_CENTER_DURATION_SEC: float = 0.3

var _orbit_centering_state: Dictionary = {}  # StringName -> {start_yaw, start_pitch, target_yaw, target_pitch, elapsed_sec, duration_sec}


func start_orbit_centering(
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
	var target_yaw: float = resolve_orbit_center_target_yaw(
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


func step_orbit_centering(vcam_id: StringName, component: Object, delta: float) -> bool:
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


func is_orbit_centering_active(vcam_id: StringName) -> bool:
	var state_variant: Variant = _orbit_centering_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		return false
	return not (state_variant as Dictionary).is_empty()


func resolve_orbit_center_target_yaw(
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


func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id != StringName(""):
			keep_ids[keep_id] = true
	for vcam_id_variant in _orbit_centering_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if not keep_ids.has(vcam_id):
			_orbit_centering_state.erase(vcam_id)


func clear_all() -> void:
	_orbit_centering_state.clear()


func clear_centering_state_for_vcam(vcam_id: StringName) -> void:
	_orbit_centering_state.erase(vcam_id)


func get_orbit_centering_state_snapshot() -> Dictionary:
	return _orbit_centering_state.duplicate(true)