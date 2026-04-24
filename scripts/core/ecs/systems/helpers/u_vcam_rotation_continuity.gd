extends RefCounted
class_name U_VCamRotationContinuity

const U_VCAM_UTILS := preload("res://scripts/utils/display/u_vcam_utils.gd")

## Handles rotation continuity when the active vCam changes.
## If the outgoing and incoming vCams share the same orbit mode and follow target,
## runtime yaw/pitch carries over. Otherwise, the incoming vCam reseeds from authored angles.

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
	return U_VCAM_UTILS.get_node_instance_id(outgoing_target) == U_VCAM_UTILS.get_node_instance_id(incoming_target)


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