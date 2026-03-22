@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VCamSystem

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_INPUT_SELECTORS := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")
const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const U_VCAM_LANDING_IMPACT := preload("res://scripts/ecs/systems/helpers/u_vcam_landing_impact.gd")
const U_VCAM_LOOK_INPUT := preload("res://scripts/ecs/systems/helpers/u_vcam_look_input.gd")
const U_VCAM_ORBIT_EFFECTS := preload("res://scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd")
const U_VCAM_RESPONSE_SMOOTHER := preload("res://scripts/ecs/systems/helpers/u_vcam_response_smoother.gd")
const U_VCAM_ROTATION := preload("res://scripts/ecs/systems/helpers/u_vcam_rotation.gd")
const U_VCAM_DEBUG := preload("res://scripts/ecs/systems/helpers/u_vcam_debug.gd")
const U_VCAM_RUNTIME_CONTEXT := preload("res://scripts/ecs/systems/helpers/u_vcam_runtime_context.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_RESPONSE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")
const RS_VCAM_SOFT_ZONE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")
const DEFAULT_LOOK_RELEASE_YAW_DAMPING: float = 10.0
const DEFAULT_LOOK_RELEASE_PITCH_DAMPING: float = 12.0
const DEFAULT_LOOK_RELEASE_STOP_THRESHOLD: float = 0.05
const DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED: float = 0.15
const DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED: float = 0.3

@export var state_store: I_StateStore = null
@export var vcam_manager: I_VCAM_MANAGER = null
@export var debug_rotation_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_rotation_log_interval_sec: float = 0.25

var _state_store: I_StateStore = null
var _vcam_manager: Node = null
var _rotation_helper = U_VCAM_ROTATION.new()
var _orbit_effects_helper = U_VCAM_ORBIT_EFFECTS.new()
var _response_smoother = U_VCAM_RESPONSE_SMOOTHER.new()
var _look_input_helper = U_VCAM_LOOK_INPUT.new()
var _landing_impact_helper = U_VCAM_LANDING_IMPACT.new()
var _debug_helper = U_VCAM_DEBUG.new()
var _runtime_context_helper = U_VCAM_RUNTIME_CONTEXT.new()
var _last_active_vcam_id: StringName = StringName("")
var _last_active_target_valid: bool = true
var _last_target_recovery_reason: String = ""
var _last_target_recovery_vcam_id: StringName = StringName("")
var _event_unsubscribers: Array[Callable] = []

var _look_rotation_state: Dictionary:
	get:
		return _rotation_helper.get_look_rotation_state_snapshot()

var _orbit_centering_state: Dictionary:
	get:
		return _rotation_helper.get_orbit_centering_state_snapshot()

var _look_ahead_state: Dictionary:
	get:
		return _orbit_effects_helper.get_look_ahead_state_snapshot()

var _ground_relative_state: Dictionary:
	get:
		return _orbit_effects_helper.get_ground_relative_state_snapshot()

var _follow_target_motion_state: Dictionary:
	get:
		return _orbit_effects_helper.get_follow_target_motion_state_snapshot()

var _soft_zone_dead_zone_state: Dictionary:
	get:
		return _orbit_effects_helper.get_soft_zone_dead_zone_state_snapshot()

var _debug_position_smoothing_bypass_by_vcam: Dictionary:
	get:
		return _orbit_effects_helper.get_position_smoothing_bypass_snapshot()

var _follow_dynamics: Dictionary:
	get:
		return _response_smoother.get_follow_dynamics_snapshot()

var _rotation_dynamics: Dictionary:
	get:
		return _response_smoother.get_rotation_dynamics_snapshot()

var _smoothing_metadata: Dictionary:
	get:
		return _response_smoother.get_smoothing_metadata_snapshot()

var _rotation_target_cache: Dictionary:
	get:
		return _response_smoother.get_rotation_target_cache_snapshot()

func on_configured() -> void:
	_debug_helper.set_state_store_provider(Callable(self, "_resolve_state_store"))
	_subscribe_events()

func process_tick(delta: float) -> void:
	_debug_helper.configure(debug_rotation_logging, debug_rotation_log_interval_sec)
	_debug_helper.tick(delta)
	var manager := _resolve_vcam_manager()
	if manager == null:
		_debug_helper.log_vcam_state("blocked: no vcam_manager service", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var active_vcam_id: StringName = manager.get_active_vcam_id()
	if active_vcam_id == StringName(""):
		_debug_helper.log_vcam_state("blocked: active_vcam_id is empty", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var vcam_index: Dictionary = _build_vcam_index()
	if vcam_index.is_empty():
		_debug_helper.log_vcam_state("blocked: vcam_index is empty", active_vcam_id, Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return
	_prune_smoothing_state(vcam_index)
	_apply_rotation_continuity_policy(active_vcam_id, vcam_index, manager)

	var look_input: Vector2 = _read_look_input()
	var move_input: Vector2 = _read_move_input()
	var camera_center_just_pressed: bool = _read_camera_center_just_pressed()
	_debug_helper.log_vcam_state("tick", active_vcam_id, look_input)
	var landing_offset: Vector3 = _resolve_landing_impact_offset(delta)
	_evaluate_and_submit(
		active_vcam_id,
		vcam_index,
		look_input,
		move_input,
		camera_center_just_pressed,
		landing_offset,
		manager,
		delta
	)

	if not manager.is_blending():
		return

	var previous_vcam_id: StringName = manager.get_previous_vcam_id()
	if previous_vcam_id == StringName("") or previous_vcam_id == active_vcam_id:
		return
	_evaluate_and_submit(
		previous_vcam_id,
		vcam_index,
		look_input,
		move_input,
		false,
		landing_offset,
		manager,
		delta
	)

func get_debug_issues() -> Array[String]:
	return _debug_helper.get_debug_issues()

func _exit_tree() -> void:
	_unsubscribe_events()
	_clear_all_smoothing_state()
	_landing_impact_helper.clear_state()
	_last_active_vcam_id = StringName("")
	_last_active_target_valid = true
	_last_target_recovery_reason = ""
	_last_target_recovery_vcam_id = StringName("")

func _subscribe_events() -> void:
	_unsubscribe_events()

func _unsubscribe_events() -> void:
	for unsubscribe in _event_unsubscribers:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribers.clear()

func _apply_rotation_continuity_policy(
	active_vcam_id: StringName,
	vcam_index: Dictionary,
	manager: I_VCAM_MANAGER
) -> void:
	if manager == null:
		return
	_rotation_helper.debug_enabled = debug_rotation_logging
	_last_active_vcam_id = _rotation_helper.apply_rotation_continuity_policy(
		active_vcam_id,
		vcam_index,
		manager.get_previous_vcam_id(),
		_last_active_vcam_id,
		Callable(self, "_resolve_follow_target"),
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT_SCRIPT
	)

func _evaluate_and_submit(
	vcam_id: StringName,
	vcam_index: Dictionary,
	look_input: Vector2,
	move_input: Vector2,
	camera_center_just_pressed: bool,
	landing_offset: Vector3,
	manager: I_VCAM_MANAGER,
	delta: float
) -> void:
	var pipeline_state: Dictionary = _prepare_vcam_pipeline_state(
		vcam_id,
		vcam_index,
		look_input,
		move_input,
		camera_center_just_pressed,
		manager,
		delta
	)
	if pipeline_state.is_empty():
		return

	var mode_result: Dictionary = _evaluate_vcam_mode_result(
		vcam_id,
		pipeline_state,
		manager,
		delta
	)
	if mode_result.is_empty():
		return

	var final_result: Dictionary = _apply_vcam_effect_pipeline(
		vcam_id,
		pipeline_state,
		mode_result,
		landing_offset,
		delta
	)
	if vcam_id == manager.get_active_vcam_id():
		_write_active_camera_base_fov_from_result(final_result)
	manager.submit_evaluated_camera(vcam_id, final_result)

func _prepare_vcam_pipeline_state(
	vcam_id: StringName,
	vcam_index: Dictionary,
	look_input: Vector2,
	move_input: Vector2,
	camera_center_just_pressed: bool,
	manager: I_VCAM_MANAGER,
	delta: float
) -> Dictionary:
	var component := vcam_index.get(vcam_id, null) as C_VCamComponent
	if component == null or not is_instance_valid(component):
		return {}

	var mode: Resource = component.mode
	if mode == null:
		return {}

	var follow_target: Node3D = _resolve_follow_target(component)
	_debug_helper.log_follow_target_resolution(vcam_id, component, follow_target)
	var follow_target_required: bool = _is_follow_target_required(mode)
	if follow_target_required and (follow_target == null or not is_instance_valid(follow_target)):
		_update_active_target_observability(vcam_id, manager, false, "target_freed")
		return {}

	var response_values: Dictionary = _resolve_component_response_values(component)
	_look_input_helper.debug_enabled = debug_rotation_logging
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
	_update_runtime_rotation(
		vcam_id,
		component,
		mode,
		follow_target,
		look_input,
		has_active_look_input,
		camera_center_just_pressed,
		response_values,
		delta
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

func _evaluate_vcam_mode_result(
	vcam_id: StringName,
	pipeline_state: Dictionary,
	manager: I_VCAM_MANAGER,
	delta: float
) -> Dictionary:
	var component := pipeline_state.get("component", null) as C_VCamComponent
	var mode := pipeline_state.get("mode", null) as Resource
	var follow_target := pipeline_state.get("follow_target", null) as Node3D
	var response_values: Dictionary = pipeline_state.get("response_values", {}) as Dictionary
	var response_signature: Array[float] = _build_response_signature(response_values)
	var has_active_look_input: bool = bool(pipeline_state.get("has_active_look_input", false))
	if component == null or mode == null:
		return {}

	var runtime_rotation: Vector2 = _resolve_runtime_rotation_for_evaluation(
		vcam_id,
		component,
		mode,
		follow_target,
		response_values,
		response_signature,
		has_active_look_input,
		delta
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
		_update_active_target_observability(vcam_id, manager, false, "evaluation_failed")
		return {}
	_update_active_target_observability(vcam_id, manager, true)
	return result

func _apply_vcam_effect_pipeline(
	vcam_id: StringName,
	pipeline_state: Dictionary,
	mode_result: Dictionary,
	landing_offset: Vector3,
	delta: float
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
		has_active_look_input
	)
	return _apply_landing_impact_offset(smoothed_result, landing_offset)

func _apply_landing_impact_offset(result: Dictionary, landing_offset: Vector3) -> Dictionary:
	_debug_helper.log_landing_offset_state(landing_offset)
	return _landing_impact_helper.apply_offset(
		result,
		landing_offset,
		Callable(self, "_apply_position_offset")
	)

func _resolve_landing_impact_offset(delta: float) -> Vector3:
	var camera_state: Object = _resolve_primary_camera_state_component()
	return _landing_impact_helper.resolve_offset(
		delta,
		camera_state,
		Callable(_runtime_context_helper, "read_camera_state_vector3"),
		Callable(_runtime_context_helper, "get_camera_state_float"),
		Callable(_runtime_context_helper, "write_camera_state_vector3"),
		C_CAMERA_STATE_COMPONENT.DEFAULT_LANDING_IMPACT_RECOVERY_SPEED
	)

func _resolve_primary_camera_state_component() -> Object:
	return _runtime_context_helper.resolve_primary_camera_state_component(
		query_entities([CAMERA_STATE_TYPE]),
		CAMERA_STATE_TYPE,
		PRIMARY_CAMERA_ENTITY_ID
	)

func _write_active_camera_base_fov_from_result(result: Dictionary) -> void:
	var camera_state: Object = _resolve_primary_camera_state_component()
	_runtime_context_helper.write_active_camera_base_fov_from_result(result, camera_state)

func _build_vcam_index() -> Dictionary:
	var index: Dictionary = {}
	var components: Array = get_components(C_VCAM_COMPONENT.COMPONENT_TYPE)
	for entry in components:
		var component := entry as C_VCamComponent
		if component == null:
			continue
		var vcam_id: StringName = _resolve_component_vcam_id(component)
		if vcam_id == StringName(""):
			continue
		if index.has(vcam_id):
			continue
		index[vcam_id] = component
	return index

func _resolve_component_vcam_id(component: C_VCamComponent) -> StringName:
	if component == null:
		return StringName("")
	if component.vcam_id != StringName(""):
		return component.vcam_id
	var fallback_id := String(component.name)
	if fallback_id.is_empty():
		return StringName("")
	return StringName(fallback_id.to_snake_case())

func _resolve_follow_target(component: C_VCamComponent) -> Node3D:
	return _runtime_context_helper.resolve_follow_target(
		component,
		get_manager(),
		Callable(_debug_helper, "report_issue")
	)

func _update_runtime_rotation(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	look_input: Vector2,
	has_look_input: bool,
	camera_center_just_pressed: bool,
	response_values: Dictionary,
	delta: float
) -> void:
	_rotation_helper.debug_enabled = debug_rotation_logging
	_rotation_helper.update_runtime_rotation(
		vcam_id,
		component,
		mode,
		follow_target,
		look_input,
		has_look_input,
		camera_center_just_pressed,
		response_values,
		delta,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT_SCRIPT
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
	var response_values: Dictionary = _resolve_component_response_values(component)
	return _orbit_effects_helper.apply_orbit_look_ahead(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT_SCRIPT,
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
	return _runtime_context_helper.resolve_look_ahead_movement_velocity(
		follow_target,
		_resolve_state_store()
	)

func _apply_orbit_ground_relative(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	response_values: Dictionary,
	delta: float
) -> Dictionary:
	return _orbit_effects_helper.apply_orbit_ground_relative(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT_SCRIPT,
		follow_target,
		result,
		response_values,
		delta,
		Callable(self, "_resolve_follow_target_grounded_state"),
		Callable(self, "_probe_ground_reference_height"),
		Callable(self, "_apply_position_offset")
	)

func _resolve_follow_target_grounded_state(follow_target: Node3D) -> bool:
	return _runtime_context_helper.resolve_follow_target_grounded_state(
		follow_target,
		_resolve_state_store()
	)

func _probe_ground_reference_height(follow_target: Node3D, max_distance: float) -> Dictionary:
	return _runtime_context_helper.probe_ground_reference_height(follow_target, max_distance)

func _apply_orbit_soft_zone(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	delta: float
) -> Dictionary:
	var soft_zone: Resource = null
	if component != null:
		soft_zone = component.soft_zone as Resource
	return _orbit_effects_helper.apply_orbit_soft_zone(
		vcam_id,
		mode,
		RS_VCAM_MODE_ORBIT_SCRIPT,
		follow_target,
		soft_zone,
		RS_VCAM_SOFT_ZONE_SCRIPT,
		result,
		delta,
		Callable(self, "_resolve_projection_camera"),
		Callable(self, "_apply_position_offset"),
		Callable(_debug_helper, "log_soft_zone_status"),
		Callable(_debug_helper, "log_soft_zone_metrics")
	)

func _resolve_projection_camera() -> Camera3D:
	return _runtime_context_helper.resolve_projection_camera(self)

func _resolve_component_response_values(component: C_VCamComponent) -> Dictionary:
	return _response_smoother.resolve_component_response_values(
		component,
		RS_VCAM_RESPONSE_SCRIPT,
		DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED,
		DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED
	)

func _build_response_signature(response_values: Dictionary) -> Array[float]:
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

func _sample_follow_target_speed(vcam_id: StringName, follow_target: Node3D, delta: float) -> float:
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

func _resolve_mode_values(mode: Resource, fallback: Dictionary) -> Dictionary:
	var resolved_values: Dictionary = {}
	if mode.has_method("get_resolved_values"):
		var resolved_variant: Variant = mode.call("get_resolved_values")
		if resolved_variant is Dictionary:
			resolved_values = (resolved_variant as Dictionary).duplicate(true)
	if resolved_values.is_empty():
		return fallback.duplicate(true)
	return resolved_values

func _prune_smoothing_state(vcam_index: Dictionary) -> void:
	var active_vcam_ids: Array = vcam_index.keys()
	_look_input_helper.prune(active_vcam_ids)
	_response_smoother.prune(active_vcam_ids)
	_rotation_helper.prune(active_vcam_ids)
	_orbit_effects_helper.prune(active_vcam_ids)
	_debug_helper.prune(active_vcam_ids)

func _clear_all_smoothing_state() -> void:
	_response_smoother.clear_all()
	_look_input_helper.clear_all()
	_orbit_effects_helper.clear_all()
	_rotation_helper.clear_all()
	_debug_helper.clear_all()

func _clear_smoothing_state_for_vcam(vcam_id: StringName) -> void:
	_response_smoother.clear_for_vcam(vcam_id)
	_look_input_helper.clear_for_vcam(vcam_id)
	_orbit_effects_helper.clear_for_vcam(vcam_id)
	_rotation_helper.clear_rotation_state_for_vcam(vcam_id)
	_debug_helper.clear_for_vcam(vcam_id)

func _resolve_runtime_rotation_for_evaluation(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	response_values: Dictionary,
	response_signature: Array[float],
	has_active_look_input: bool,
	delta: float
) -> Vector2:
	_rotation_helper.debug_enabled = debug_rotation_logging
	return _rotation_helper.resolve_runtime_rotation_for_evaluation(
		vcam_id,
		component,
		mode,
		follow_target,
		response_values,
		response_signature,
		has_active_look_input,
		delta,
		RS_VCAM_MODE_ORBIT_SCRIPT
	)

func _step_orbit_release_axis(
	_vcam_id: StringName,
	_axis_label: String,
	current_value: float,
	target_value: float,
	current_velocity: float,
	frequency_hz: float,
	damping_ratio: float,
	release_damping: float,
	stop_threshold: float,
	delta: float
) -> Dictionary:
	return _rotation_helper.step_orbit_release_axis(
		current_value,
		target_value,
		current_velocity,
		frequency_hz,
		damping_ratio,
		release_damping,
		stop_threshold,
		delta
	)

func _resolve_orbit_center_target_yaw(
	mode: Resource,
	follow_target: Node3D,
	current_runtime_yaw: float
) -> float:
	return _rotation_helper.resolve_orbit_center_target_yaw(
		mode,
		follow_target,
		current_runtime_yaw,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT_SCRIPT
	)

func _apply_response_smoothing(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	raw_result: Dictionary,
	delta: float,
	has_active_look_input: bool
) -> Dictionary:
	if component == null:
		return raw_result
	if mode == null:
		return raw_result

	var response_values: Dictionary = _resolve_component_response_values(component)
	if response_values.is_empty():
		_clear_smoothing_state_for_vcam(vcam_id)
		return raw_result
	var response_signature: Array[float] = _build_response_signature(response_values)
	var mode_script := mode.get_script() as Script
	var follow_target_id: int = _get_node_instance_id(follow_target)
	var follow_target_speed_mps: float = _sample_follow_target_speed(vcam_id, follow_target, delta)
	return _response_smoother.apply_response_smoothing(
		vcam_id,
		mode_script,
		RS_VCAM_MODE_ORBIT_SCRIPT,
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

func _get_node_instance_id(node: Node) -> int:
	if node == null:
		return 0
	if not is_instance_valid(node):
		return 0
	return node.get_instance_id()

func _resolve_vcam_manager() -> I_VCAM_MANAGER:
	if _vcam_manager != null and is_instance_valid(_vcam_manager):
		return _vcam_manager as I_VCAM_MANAGER

	if vcam_manager != null and is_instance_valid(vcam_manager):
		_vcam_manager = vcam_manager
		return _vcam_manager as I_VCAM_MANAGER

	var service: Node = U_SERVICE_LOCATOR.try_get_service(StringName("vcam_manager"))
	if service == null or not is_instance_valid(service):
		return null
	if not (service is I_VCAM_MANAGER):
		return null

	_vcam_manager = service
	return _vcam_manager as I_VCAM_MANAGER

func _update_active_target_observability(
	vcam_id: StringName,
	manager: I_VCAM_MANAGER,
	is_valid: bool,
	recovery_reason: String = ""
) -> void:
	if manager == null:
		return
	if vcam_id != manager.get_active_vcam_id():
		return
	var store := _resolve_state_store()
	if _last_active_target_valid != is_valid:
		_last_active_target_valid = is_valid
		if store != null:
			store.dispatch(U_VCAM_ACTIONS.update_target_validity(is_valid))
	if is_valid:
		_last_target_recovery_reason = ""
		_last_target_recovery_vcam_id = StringName("")
		return
	if recovery_reason.is_empty():
		return
	if recovery_reason == _last_target_recovery_reason and vcam_id == _last_target_recovery_vcam_id:
		return
	_last_target_recovery_reason = recovery_reason
	_last_target_recovery_vcam_id = vcam_id
	if store != null:
		store.dispatch(U_VCAM_ACTIONS.record_recovery(recovery_reason))
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_VCAM_RECOVERY, {
		"reason": recovery_reason,
		"vcam_id": vcam_id,
		"active_vcam_id": manager.get_active_vcam_id(),
		"previous_vcam_id": manager.get_previous_vcam_id(),
	})
	manager.set_active_vcam(StringName(""))

func _is_follow_target_required(mode: Resource) -> bool:
	if mode == null:
		return false
	var mode_script := mode.get_script() as Script
	return mode_script == RS_VCAM_MODE_ORBIT_SCRIPT

func _resolve_state_store() -> I_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	if state_store != null and is_instance_valid(state_store):
		_state_store = state_store
		return _state_store
	_state_store = U_STATE_UTILS.try_get_store(self)
	return _state_store

func _read_look_input() -> Vector2:
	var store := _resolve_state_store()
	if store == null:
		return Vector2.ZERO
	var state: Dictionary = store.get_state()
	return U_INPUT_SELECTORS.get_look_input(state)

func _read_move_input() -> Vector2:
	var store := _resolve_state_store()
	if store == null:
		return Vector2.ZERO
	var state: Dictionary = store.get_state()
	return U_INPUT_SELECTORS.get_move_input(state)

func _read_camera_center_just_pressed() -> bool:
	var store := _resolve_state_store()
	if store == null:
		return false
	var state: Dictionary = store.get_state()
	return U_INPUT_SELECTORS.is_camera_center_just_pressed(state)
