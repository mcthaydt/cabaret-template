@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VCamSystem

const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const U_VCAM_LANDING_IMPACT := preload("res://scripts/ecs/systems/helpers/u_vcam_landing_impact.gd")
const U_VCAM_LOOK_INPUT := preload("res://scripts/ecs/systems/helpers/u_vcam_look_input.gd")
const U_VCAM_ORBIT_EFFECTS := preload("res://scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd")
const U_VCAM_RESPONSE_SMOOTHER := preload("res://scripts/ecs/systems/helpers/u_vcam_response_smoother.gd")
const U_VCAM_ROTATION := preload("res://scripts/ecs/systems/helpers/u_vcam_rotation.gd")
const U_VCAM_DEBUG := preload("res://scripts/ecs/systems/helpers/u_vcam_debug.gd")
const U_VCAM_EFFECT_PIPELINE := preload("res://scripts/ecs/systems/helpers/u_vcam_effect_pipeline.gd")
const U_VCAM_RUNTIME_CONTEXT := preload("res://scripts/ecs/systems/helpers/u_vcam_runtime_context.gd")
const U_VCAM_RUNTIME_STATE := preload("res://scripts/ecs/systems/helpers/u_vcam_runtime_state.gd")
const U_VCAM_RUNTIME_SERVICES := preload("res://scripts/ecs/systems/helpers/u_vcam_runtime_services.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_RESPONSE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")
const RS_VCAM_SOFT_ZONE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")
const U_PERF_PROBE_SCRIPT := preload("res://scripts/utils/debug/u_perf_probe.gd")

@export var state_store: I_StateStore = null
@export var vcam_manager: I_VCAM_MANAGER = null
@export var debug_rotation_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_rotation_log_interval_sec: float = 0.25

var _rotation_helper = U_VCAM_ROTATION.new()
var _orbit_effects_helper = U_VCAM_ORBIT_EFFECTS.new()
var _response_smoother = U_VCAM_RESPONSE_SMOOTHER.new()
var _look_input_helper = U_VCAM_LOOK_INPUT.new()
var _landing_impact_helper = U_VCAM_LANDING_IMPACT.new()
var _debug_helper = U_VCAM_DEBUG.new()
var _effect_pipeline_helper = U_VCAM_EFFECT_PIPELINE.new()
var _runtime_context_helper = U_VCAM_RUNTIME_CONTEXT.new()
var _runtime_state_helper = U_VCAM_RUNTIME_STATE.new()
var _runtime_services_helper = U_VCAM_RUNTIME_SERVICES.new()
var _state_store: I_StateStore = null
var _vcam_manager: I_VCAM_MANAGER = null
var _last_active_vcam_id: StringName = StringName("")

# Mobile perf probes
var _probe_total_tick = U_PERF_PROBE_SCRIPT.new("vcam_total_tick")
var _probe_prepare = U_PERF_PROBE_SCRIPT.new("vcam_prepare_pipeline")
var _probe_evaluate = U_PERF_PROBE_SCRIPT.new("vcam_evaluate_mode")
var _probe_effect_pipeline = U_PERF_PROBE_SCRIPT.new("vcam_effect_pipeline")

@warning_ignore("unused_private_class_variable")
var _look_rotation_state: Dictionary:
	get:
		return _rotation_helper.get_look_rotation_state_snapshot()

@warning_ignore("unused_private_class_variable")
var _orbit_centering_state: Dictionary:
	get:
		return _rotation_helper.get_orbit_centering_state_snapshot()

@warning_ignore("unused_private_class_variable")
var _look_ahead_state: Dictionary:
	get:
		return _orbit_effects_helper.get_look_ahead_state_snapshot()

@warning_ignore("unused_private_class_variable")
var _ground_relative_state: Dictionary:
	get:
		return _orbit_effects_helper.get_ground_relative_state_snapshot()

@warning_ignore("unused_private_class_variable")
var _follow_target_motion_state: Dictionary:
	get:
		return _orbit_effects_helper.get_follow_target_motion_state_snapshot()

@warning_ignore("unused_private_class_variable")
var _soft_zone_dead_zone_state: Dictionary:
	get:
		return _orbit_effects_helper.get_soft_zone_dead_zone_state_snapshot()

@warning_ignore("unused_private_class_variable")
var _debug_position_smoothing_bypass_by_vcam: Dictionary:
	get:
		return _orbit_effects_helper.get_position_smoothing_bypass_snapshot()

@warning_ignore("unused_private_class_variable")
var _follow_dynamics: Dictionary:
	get:
		return _response_smoother.get_follow_dynamics_snapshot()

@warning_ignore("unused_private_class_variable")
var _rotation_dynamics: Dictionary:
	get:
		return _response_smoother.get_rotation_dynamics_snapshot()

@warning_ignore("unused_private_class_variable")
var _smoothing_metadata: Dictionary:
	get:
		return _response_smoother.get_smoothing_metadata_snapshot()

@warning_ignore("unused_private_class_variable")
var _rotation_target_cache: Dictionary:
	get:
		return _response_smoother.get_rotation_target_cache_snapshot()

func on_configured() -> void:
	_runtime_services_helper.configure(self, state_store, vcam_manager)
	_effect_pipeline_helper.configure(
		self,
		_orbit_effects_helper,
		_response_smoother,
		_landing_impact_helper,
		_debug_helper,
		_runtime_context_helper,
		_runtime_services_helper,
		RS_VCAM_MODE_ORBIT_SCRIPT,
		RS_VCAM_SOFT_ZONE_SCRIPT,
		RS_VCAM_RESPONSE_SCRIPT
	)
	_debug_helper.set_state_store_provider(Callable(_runtime_services_helper, "resolve_state_store"))

func process_tick(delta: float) -> void:
	var _pt_total_start: int = _probe_total_tick.begin()
	_debug_helper.configure(debug_rotation_logging, debug_rotation_log_interval_sec)
	_debug_helper.tick(delta)
	var manager := _runtime_services_helper.resolve_vcam_manager()
	_vcam_manager = manager
	if manager == null:
		_debug_helper.log_vcam_state("blocked: no vcam_manager service", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		_probe_total_tick.end(_pt_total_start)
		_probe_total_tick.tick_and_maybe_log()
		_runtime_context_helper.log_obj_prop_stats_and_reset()
		return

	var active_vcam_id: StringName = manager.get_active_vcam_id()
	if active_vcam_id == StringName(""):
		_debug_helper.log_vcam_state("blocked: active_vcam_id is empty", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		_probe_total_tick.end(_pt_total_start)
		_probe_total_tick.tick_and_maybe_log()
		_runtime_context_helper.log_obj_prop_stats_and_reset()
		return

	var vcam_index: Dictionary = _runtime_services_helper.build_vcam_index(
		get_components(C_VCAM_COMPONENT.COMPONENT_TYPE)
	)
	if vcam_index.is_empty():
		_debug_helper.log_vcam_state("blocked: vcam_index is empty", active_vcam_id, Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		_probe_total_tick.end(_pt_total_start)
		_probe_total_tick.tick_and_maybe_log()
		_runtime_context_helper.log_obj_prop_stats_and_reset()
		return
	_prune_smoothing_state(vcam_index)
	_apply_rotation_continuity_policy(active_vcam_id, vcam_index, manager)

	var store := _runtime_services_helper.resolve_state_store()
	_state_store = store
	var state_snapshot: Dictionary = _get_frame_state_snapshot()
	var look_input: Vector2 = _runtime_state_helper.read_look_input(store, state_snapshot)
	var move_input: Vector2 = _runtime_state_helper.read_move_input(store, state_snapshot)
	var camera_center_just_pressed: bool = _runtime_state_helper.read_camera_center_just_pressed(store, state_snapshot)
	_debug_helper.log_vcam_state("tick", active_vcam_id, look_input)
	var landing_offset: Vector3 = _resolve_landing_impact_offset(delta)

	var _pt_prepare_start: int = _probe_prepare.begin()
	var pipeline_state: Dictionary = _prepare_vcam_pipeline_state(
		active_vcam_id, vcam_index, look_input, move_input,
		camera_center_just_pressed, manager, delta
	)
	_probe_prepare.end(_pt_prepare_start)
	if not pipeline_state.is_empty():
		var _pt_eval_start: int = _probe_evaluate.begin()
		var mode_result: Dictionary = _evaluate_vcam_mode_result(
			active_vcam_id, pipeline_state, manager, delta
		)
		_probe_evaluate.end(_pt_eval_start)
		if not mode_result.is_empty():
			var _pt_pipe_start: int = _probe_effect_pipeline.begin()
			var final_result: Dictionary = _apply_vcam_effect_pipeline(
				active_vcam_id, pipeline_state, mode_result, landing_offset, delta
			)
			_probe_effect_pipeline.end(_pt_pipe_start)
			if active_vcam_id == manager.get_active_vcam_id():
				_write_active_camera_base_fov_from_result(final_result)
			manager.submit_evaluated_camera(active_vcam_id, final_result)

	if not manager.is_blending():
		_probe_total_tick.end(_pt_total_start)
		_probe_total_tick.tick_and_maybe_log()
		_runtime_context_helper.log_obj_prop_stats_and_reset()
		return

	var previous_vcam_id: StringName = manager.get_previous_vcam_id()
	if previous_vcam_id == StringName("") or previous_vcam_id == active_vcam_id:
		_probe_total_tick.end(_pt_total_start)
		_probe_total_tick.tick_and_maybe_log()
		_runtime_context_helper.log_obj_prop_stats_and_reset()
		return

	var _pt_prepare2_start: int = _probe_prepare.begin()
	var pipeline_state_prev: Dictionary = _prepare_vcam_pipeline_state(
		previous_vcam_id, vcam_index, look_input, move_input, false, manager, delta
	)
	_probe_prepare.end(_pt_prepare2_start)
	if not pipeline_state_prev.is_empty():
		var _pt_eval2_start: int = _probe_evaluate.begin()
		var mode_result_prev: Dictionary = _evaluate_vcam_mode_result(
			previous_vcam_id, pipeline_state_prev, manager, delta
		)
		_probe_evaluate.end(_pt_eval2_start)
		if not mode_result_prev.is_empty():
			var _pt_pipe2_start: int = _probe_effect_pipeline.begin()
			var final_result_prev: Dictionary = _apply_vcam_effect_pipeline(
				previous_vcam_id, pipeline_state_prev, mode_result_prev, landing_offset, delta
			)
			_probe_effect_pipeline.end(_pt_pipe2_start)
			if previous_vcam_id == manager.get_active_vcam_id():
				_write_active_camera_base_fov_from_result(final_result_prev)
			manager.submit_evaluated_camera(previous_vcam_id, final_result_prev)

	_probe_total_tick.end(_pt_total_start)
	_probe_total_tick.tick_and_maybe_log()

func get_debug_issues() -> Array[String]:
	return _debug_helper.get_debug_issues()

func _exit_tree() -> void:
	_clear_all_smoothing_state()
	_landing_impact_helper.clear_state()
	_state_store = null
	_vcam_manager = null
	_last_active_vcam_id = StringName("")
	_runtime_state_helper.reset_observability_state()


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
	_move_input: Vector2,
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
	var follow_target_required: bool = _runtime_services_helper.is_follow_target_required(
		mode,
		RS_VCAM_MODE_ORBIT_SCRIPT
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
	var response_signature: Array[float] = _effect_pipeline_helper.build_response_signature(response_values)
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

func _apply_vcam_effect_pipeline(
	vcam_id: StringName,
	pipeline_state: Dictionary,
	mode_result: Dictionary,
	landing_offset: Vector3,
	delta: float
) -> Dictionary:
	return _effect_pipeline_helper.apply_vcam_effect_pipeline(
		vcam_id,
		pipeline_state,
		mode_result,
		landing_offset,
		delta,
		Callable(self, "_clear_smoothing_state_for_vcam")
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

func _get_frame_state_snapshot() -> Dictionary:
	var manager := get_manager()
	if manager != null and manager.has_method("get_frame_state_snapshot"):
		return manager.get_frame_state_snapshot()
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store.get_state()
	var store := _runtime_services_helper.resolve_state_store()
	if store != null:
		return store.get_state()
	return {}
