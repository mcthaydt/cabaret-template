extends RefCounted
class_name U_VCamPipelineHelper
## Orchestrates vCam pipeline stages: prepare + evaluate via decomposed helpers.

const U_VCAM_MODE_EVALUATOR := preload("res://scripts/core/managers/helpers/u_vcam_mode_evaluator.gd")
const C_VCAM_COMPONENT := preload("res://scripts/core/ecs/components/c_vcam_component.gd")
const U_VCAM_EFFECT_PIPELINE := preload("res://scripts/core/ecs/systems/helpers/u_vcam_effect_pipeline.gd")
const U_VCAM_LOOK_INPUT := preload("res://scripts/core/ecs/systems/helpers/u_vcam_look_input.gd")
const U_VCAM_ROTATION := preload("res://scripts/core/ecs/systems/helpers/u_vcam_rotation.gd")
const U_VCAM_DEBUG := preload("res://scripts/core/ecs/systems/helpers/u_vcam_debug.gd")
const U_VCAM_RUNTIME_SERVICES := preload("res://scripts/core/ecs/systems/helpers/u_vcam_runtime_services.gd")
const U_VCAM_RUNTIME_STATE := preload("res://scripts/core/ecs/systems/helpers/u_vcam_runtime_state.gd")

var _effect_pipeline_helper: U_VCamEffectPipeline = null
var _look_input_helper: U_VCamLookInput = null
var _rotation_helper: U_VCamRotation = null
var _debug_helper: U_VCamDebug = null
var _runtime_services_helper: U_VCamRuntimeServices = null
var _runtime_state_helper: U_VCamRuntimeState = null
var _resolve_follow_target: Callable = Callable()
var _resolve_mode_values: Callable = Callable()
var _orbit_mode_script: Script = null

var debug_enabled: bool = false


func configure(
	effect_pipeline_helper: U_VCamEffectPipeline,
	look_input_helper: U_VCamLookInput,
	rotation_helper: U_VCamRotation,
	debug_helper: U_VCamDebug,
	runtime_services_helper: U_VCamRuntimeServices,
	runtime_state_helper: U_VCamRuntimeState,
	resolve_follow_target: Callable,
	resolve_mode_values: Callable,
	orbit_mode_script: Script
) -> void:
	_effect_pipeline_helper = effect_pipeline_helper
	_look_input_helper = look_input_helper
	_rotation_helper = rotation_helper
	_debug_helper = debug_helper
	_runtime_services_helper = runtime_services_helper
	_runtime_state_helper = runtime_state_helper
	_resolve_follow_target = resolve_follow_target
	_resolve_mode_values = resolve_mode_values
	_orbit_mode_script = orbit_mode_script


func prepare_vcam_pipeline_state(
	vcam_id: StringName,
	vcam_index: Dictionary,
	look_input: Vector2,
	_move_input: Vector2,
	camera_center_just_pressed: bool,
	manager,
	delta: float
) -> Dictionary:
	var component := vcam_index.get(vcam_id, null) as C_VCamComponent
	if component == null or not is_instance_valid(component):
		return {}

	var mode: Resource = component.mode
	if mode == null:
		return {}

	var follow_target: Node3D = _resolve_follow_target.call(component) if _resolve_follow_target.is_valid() else null
	_debug_helper.log_follow_target_resolution(vcam_id, component, follow_target)
	var follow_target_required: bool = _runtime_services_helper.is_follow_target_required(
		mode,
		_orbit_mode_script
	)
	if follow_target_required and (follow_target == null or not is_instance_valid(follow_target)):
		_runtime_state_helper.update_active_target_observability(
			vcam_id,
			manager,
			false,
			"target_freed",
			_runtime_services_helper.resolve_state_store()
		)
		return {}

	var response_values: Dictionary = _effect_pipeline_helper.resolve_component_response_values(component)
	_look_input_helper.debug_enabled = debug_enabled
	var filtered_look_input: Vector2 = _look_input_helper.filter_look_input(
		vcam_id,
		look_input,
		response_values,
		delta
	)
	var has_active_look_input: bool = _look_input_helper.is_active(
		filtered_look_input,
		response_values
	)
	_rotation_helper.debug_enabled = debug_enabled
	_rotation_helper.update_runtime_rotation(
		vcam_id,
		component,
		mode,
		follow_target,
		look_input,
		has_active_look_input,
		camera_center_just_pressed,
		response_values,
		delta,
		_resolve_mode_values,
		_orbit_mode_script
	)
	if _rotation_helper.is_orbit_centering_active(vcam_id):
		has_active_look_input = false
	_debug_helper.log_look_input_transition(vcam_id, filtered_look_input)

	return {
		"component": component,
		"mode": mode,
		"follow_target": follow_target,
		"response_values": response_values,
		"has_active_look_input": has_active_look_input,
	}


func evaluate_vcam_mode_result(
	vcam_id: StringName,
	pipeline_state: Dictionary,
	manager,
	delta: float
) -> Dictionary:
	var component := pipeline_state.get("component", null) as C_VCamComponent
	var mode := pipeline_state.get("mode", null) as Resource
	var follow_target := pipeline_state.get("follow_target", null) as Node3D
	var response_values: Dictionary = pipeline_state.get("response_values", {}) as Dictionary
	var response_signature: Array[float] = _effect_pipeline_helper.build_response_signature(response_values)
	var has_active_look_input: bool = bool(pipeline_state.get("has_active_look_input", false))
	if component == null or mode == null:
		return {}

	var runtime_rotation: Vector2 = _rotation_helper.resolve_runtime_rotation_for_evaluation(
		vcam_id,
		component,
		mode,
		follow_target,
		response_values,
		response_signature,
		has_active_look_input,
		delta,
		_orbit_mode_script
	)
	var look_at_target: Node3D = component.get_look_at_target()
	var result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		look_at_target,
		runtime_rotation.x,
		runtime_rotation.y
	)
	if result.is_empty():
		_runtime_state_helper.update_active_target_observability(
			vcam_id,
			manager,
			false,
			"evaluation_failed",
			_runtime_services_helper.resolve_state_store()
		)
		return {}
	_runtime_state_helper.update_active_target_observability(
		vcam_id,
		manager,
		true,
		"",
		_runtime_services_helper.resolve_state_store()
	)
	return result