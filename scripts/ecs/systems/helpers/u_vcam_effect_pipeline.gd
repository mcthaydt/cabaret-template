extends RefCounted
class_name U_VCamEffectPipeline

const U_VCAM_LOOK_INPUT := preload("res://scripts/ecs/systems/helpers/u_vcam_look_input.gd")
const U_VCAM_ORBIT_EFFECTS := preload("res://scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd")
const U_VCAM_RESPONSE_SMOOTHER := preload("res://scripts/ecs/systems/helpers/u_vcam_response_smoother.gd")
const U_VCAM_LANDING_IMPACT := preload("res://scripts/ecs/systems/helpers/u_vcam_landing_impact.gd")
const U_VCAM_DEBUG := preload("res://scripts/ecs/systems/helpers/u_vcam_debug.gd")
const U_VCAM_RUNTIME_CONTEXT := preload("res://scripts/ecs/systems/helpers/u_vcam_runtime_context.gd")
const U_VCAM_RUNTIME_SERVICES := preload("res://scripts/ecs/systems/helpers/u_vcam_runtime_services.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")

const DEFAULT_LOOK_RELEASE_YAW_DAMPING: float = 10.0
const DEFAULT_LOOK_RELEASE_PITCH_DAMPING: float = 12.0
const DEFAULT_LOOK_RELEASE_STOP_THRESHOLD: float = 0.05
const DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED: float = 0.15
const DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED: float = 0.3

var _owner: Node = null
var _orbit_effects_helper: U_VCamOrbitEffects = null
var _response_smoother: U_VCamResponseSmoother = null
var _landing_impact_helper: U_VCamLandingImpact = null
var _debug_helper: U_VCamDebug = null
var _runtime_context_helper: U_VCamRuntimeContext = null
var _runtime_services_helper: U_VCamRuntimeServices = null
var _orbit_mode_script: Script = null
var _soft_zone_script: Script = null
var _response_script: Script = null

func configure(
	owner: Node,
	orbit_effects_helper: U_VCamOrbitEffects,
	response_smoother: U_VCamResponseSmoother,
	landing_impact_helper: U_VCamLandingImpact,
	debug_helper: U_VCamDebug,
	runtime_context_helper: U_VCamRuntimeContext,
	runtime_services_helper: U_VCamRuntimeServices,
	orbit_mode_script: Script,
	soft_zone_script: Script,
	response_script: Script
) -> void:
	_owner = owner
	_orbit_effects_helper = orbit_effects_helper
	_response_smoother = response_smoother
	_landing_impact_helper = landing_impact_helper
	_debug_helper = debug_helper
	_runtime_context_helper = runtime_context_helper
	_runtime_services_helper = runtime_services_helper
	_orbit_mode_script = orbit_mode_script
	_soft_zone_script = soft_zone_script
	_response_script = response_script

func resolve_component_response_values(component: C_VCamComponent) -> Dictionary:
	if _response_smoother == null:
		return {}
	return _response_smoother.resolve_component_response_values(
		component,
		_response_script,
		DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED,
		DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED
	)

func build_response_signature(response_values: Dictionary) -> Array[float]:
	if _response_smoother == null:
		return []
	return _response_smoother.build_response_signature(
		response_values,
		U_VCAM_LOOK_INPUT.DEFAULT_LOOK_INPUT_DEADZONE,
		U_VCAM_LOOK_INPUT.DEFAULT_LOOK_INPUT_HOLD_SEC,
		U_VCAM_LOOK_INPUT.DEFAULT_LOOK_INPUT_RELEASE_DECAY,
		DEFAULT_LOOK_RELEASE_YAW_DAMPING,
		DEFAULT_LOOK_RELEASE_PITCH_DAMPING,
		DEFAULT_LOOK_RELEASE_STOP_THRESHOLD,
		DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED,
		DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED
	)

func apply_vcam_effect_pipeline(
	vcam_id: StringName,
	pipeline_state: Dictionary,
	mode_result: Dictionary,
	landing_offset: Vector3,
	delta: float,
	clear_smoothing_state_for_vcam: Callable
) -> Dictionary:
	var component := pipeline_state.get("component", null) as C_VCamComponent
	var mode := pipeline_state.get("mode", null) as Resource
	var follow_target := pipeline_state.get("follow_target", null) as Node3D
	var response_values: Dictionary = pipeline_state.get("response_values", {}) as Dictionary
	var has_active_look_input: bool = bool(pipeline_state.get("has_active_look_input", false))
	if component == null or mode == null:
		return mode_result

	var look_ahead_result: Dictionary = _apply_orbit_look_ahead(
		vcam_id,
		component,
		mode,
		follow_target,
		mode_result,
		has_active_look_input,
		delta
	)
	var ground_relative_result: Dictionary = _apply_orbit_ground_relative(
		vcam_id,
		component,
		mode,
		follow_target,
		look_ahead_result,
		response_values,
		delta
	)
	var soft_zone_result: Dictionary = _apply_orbit_soft_zone(
		vcam_id,
		component,
		mode,
		follow_target,
		ground_relative_result,
		delta
	)
	var smoothed_result: Dictionary = _apply_response_smoothing(
		vcam_id,
		component,
		mode,
		follow_target,
		soft_zone_result,
		delta,
		has_active_look_input,
		clear_smoothing_state_for_vcam
	)
	return _apply_landing_impact_offset(smoothed_result, landing_offset)

func _apply_landing_impact_offset(result: Dictionary, landing_offset: Vector3) -> Dictionary:
	if _debug_helper != null:
		_debug_helper.log_landing_offset_state(landing_offset)
	if _landing_impact_helper == null:
		return result
	return _landing_impact_helper.apply_offset(
		result,
		landing_offset,
		Callable(self, "_apply_position_offset")
	)

func _apply_orbit_look_ahead(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	has_active_look_input: bool,
	delta: float
) -> Dictionary:
	if _orbit_effects_helper == null:
		return result
	var response_values: Dictionary = resolve_component_response_values(component)
	return _orbit_effects_helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		_orbit_mode_script,
		follow_target,
		result,
		response_values,
		has_active_look_input,
		delta,
		Callable(self, "_resolve_look_ahead_movement_velocity"),
		Callable(self, "_apply_position_offset"),
		Callable(_debug_helper, "log_look_ahead_motion_state")
	)

func _resolve_look_ahead_movement_velocity(follow_target: Node3D) -> Dictionary:
	if _runtime_context_helper == null or _runtime_services_helper == null:
		return {}
	return _runtime_context_helper.resolve_look_ahead_movement_velocity(
		follow_target,
		_runtime_services_helper.resolve_state_store()
	)

func _apply_orbit_ground_relative(
	vcam_id: StringName,
	_component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	response_values: Dictionary,
	delta: float
) -> Dictionary:
	if _orbit_effects_helper == null:
		return result
	return _orbit_effects_helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		_orbit_mode_script,
		follow_target,
		result,
		response_values,
		delta,
		Callable(self, "_resolve_follow_target_grounded_state"),
		Callable(self, "_probe_ground_reference_height"),
		Callable(self, "_apply_position_offset")
	)

func _resolve_follow_target_grounded_state(follow_target: Node3D) -> bool:
	if _runtime_context_helper == null or _runtime_services_helper == null:
		return false
	return _runtime_context_helper.resolve_follow_target_grounded_state(
		follow_target,
		_runtime_services_helper.resolve_state_store()
	)

func _probe_ground_reference_height(follow_target: Node3D, max_distance: float) -> Dictionary:
	if _runtime_context_helper == null:
		return {}
	return _runtime_context_helper.probe_ground_reference_height(follow_target, max_distance)

func _apply_orbit_soft_zone(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	delta: float
) -> Dictionary:
	if _orbit_effects_helper == null:
		return result
	var soft_zone: Resource = null
	if component != null:
		soft_zone = component.soft_zone as Resource
	return _orbit_effects_helper.apply_orbit_soft_zone(
		vcam_id,
		mode,
		_orbit_mode_script,
		follow_target,
		soft_zone,
		_soft_zone_script,
		result,
		delta,
		Callable(self, "_resolve_projection_camera"),
		Callable(self, "_apply_position_offset"),
		Callable(_debug_helper, "log_soft_zone_status"),
		Callable(_debug_helper, "log_soft_zone_metrics")
	)

func _resolve_projection_camera() -> Camera3D:
	if _runtime_context_helper == null:
		return null
	return _runtime_context_helper.resolve_projection_camera(_owner)

func _sample_follow_target_speed(vcam_id: StringName, follow_target: Node3D, delta: float) -> float:
	if _orbit_effects_helper == null:
		return 0.0
	return _orbit_effects_helper.sample_follow_target_speed(vcam_id, follow_target, delta)

func _apply_position_offset(result: Dictionary, offset: Vector3) -> Dictionary:
	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result
	var transform := transform_variant as Transform3D
	var offset_result: Dictionary = result.duplicate(true)
	var offset_transform := transform
	offset_transform.origin += offset
	offset_result["transform"] = offset_transform
	return offset_result

func _apply_response_smoothing(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	raw_result: Dictionary,
	delta: float,
	has_active_look_input: bool,
	clear_smoothing_state_for_vcam: Callable
) -> Dictionary:
	if component == null or mode == null or _response_smoother == null:
		return raw_result

	var response_values: Dictionary = resolve_component_response_values(component)
	if response_values.is_empty():
		if clear_smoothing_state_for_vcam.is_valid():
			clear_smoothing_state_for_vcam.call(vcam_id)
		return raw_result
	var response_signature: Array[float] = build_response_signature(response_values)
	var mode_script := mode.get_script() as Script
	var follow_target_id: int = 0
	if _runtime_services_helper != null:
		follow_target_id = _runtime_services_helper.get_node_instance_id(follow_target)
	var follow_target_speed_mps: float = _sample_follow_target_speed(vcam_id, follow_target, delta)
	return _response_smoother.apply_response_smoothing(
		vcam_id,
		mode_script,
		_orbit_mode_script,
		follow_target_id,
		follow_target_speed_mps,
		raw_result,
		delta,
		has_active_look_input,
		response_values,
		response_signature,
		Callable(_orbit_effects_helper, "update_orbit_position_smoothing_bypass"),
		DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED,
		DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED,
		Callable(_debug_helper, "log_position_smoothing_gate_transition"),
		Callable(_debug_helper, "log_rotation")
	)