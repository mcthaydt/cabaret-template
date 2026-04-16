@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VCamSystem

const U_VCAM_PIPELINE_BUILDER := preload("res://scripts/ecs/systems/helpers/u_vcam_pipeline_builder.gd")
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
var _pipeline_builder = U_VCAM_PIPELINE_BUILDER.new()
var _state_store: I_StateStore = null
var _vcam_manager: I_VCAM_MANAGER = null
var _last_active_vcam_id: StringName = StringName("")

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
	_pipeline_builder.configure(
		_effect_pipeline_helper,
		_look_input_helper,
		_rotation_helper,
		_debug_helper,
		_runtime_services_helper,
		_runtime_state_helper,
		Callable(self, "_resolve_follow_target"),
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT_SCRIPT
	)

func process_tick(delta: float) -> void:
	_debug_helper.configure(debug_rotation_logging, debug_rotation_log_interval_sec)
	_debug_helper.tick(delta)
	var manager := _runtime_services_helper.resolve_vcam_manager()
	_vcam_manager = manager
	if manager == null:
		_debug_helper.log_vcam_state("blocked: no vcam_manager service", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var active_vcam_id: StringName = manager.get_active_vcam_id()
	if active_vcam_id == StringName(""):
		_debug_helper.log_vcam_state("blocked: active_vcam_id is empty", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var vcam_index: Dictionary = _runtime_services_helper.build_vcam_index(
		get_components(C_VCAM_COMPONENT.COMPONENT_TYPE)
	)
	if vcam_index.is_empty():
		_debug_helper.log_vcam_state("blocked: vcam_index is empty", active_vcam_id, Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return
	_prune_smoothing_state(vcam_index)
	_apply_rotation_continuity_policy(active_vcam_id, vcam_index, manager)

	var store := _runtime_services_helper.resolve_state_store()
	_state_store = store
	var state_snapshot: Dictionary = get_frame_state_snapshot()
	var input_state_snapshot: Dictionary = state_snapshot
	if store != null and is_instance_valid(store):
		# Read directly from store so vCam reacts without a one-frame delay.
		input_state_snapshot = store.get_state()
	var look_input: Vector2 = _runtime_state_helper.read_look_input(null, input_state_snapshot)
	var move_input: Vector2 = _runtime_state_helper.read_move_input(null, input_state_snapshot)
	var camera_center_just_pressed: bool = _runtime_state_helper.read_camera_center_just_pressed(null, input_state_snapshot)
	_debug_helper.log_vcam_state("tick", active_vcam_id, look_input)
	var landing_offset: Vector3 = _resolve_landing_impact_offset(delta)
	_pipeline_builder.debug_enabled = debug_rotation_logging
	var pipeline_state: Dictionary = _pipeline_builder.prepare_vcam_pipeline_state(
		active_vcam_id, vcam_index, look_input, move_input,
		camera_center_just_pressed, manager, delta
	)
	if not pipeline_state.is_empty():
		var mode_result: Dictionary = _pipeline_builder.evaluate_vcam_mode_result(
			active_vcam_id, pipeline_state, manager, delta
		)
		if not mode_result.is_empty():
			var final_result: Dictionary = _effect_pipeline_helper.apply_vcam_effect_pipeline(
				active_vcam_id, pipeline_state, mode_result, landing_offset, delta,
				Callable(self, "_clear_smoothing_state_for_vcam")
			)
			if active_vcam_id == manager.get_active_vcam_id():
				_write_active_camera_base_fov_from_result(final_result)
			manager.submit_evaluated_camera(active_vcam_id, final_result)

	if not manager.is_blending():
		return

	var previous_vcam_id: StringName = manager.get_previous_vcam_id()
	if previous_vcam_id == StringName("") or previous_vcam_id == active_vcam_id:
		return

	var pipeline_state_prev: Dictionary = _pipeline_builder.prepare_vcam_pipeline_state(
		previous_vcam_id, vcam_index, look_input, move_input, false, manager, delta
	)
	if not pipeline_state_prev.is_empty():
		var mode_result_prev: Dictionary = _pipeline_builder.evaluate_vcam_mode_result(
			previous_vcam_id, pipeline_state_prev, manager, delta
		)
		if not mode_result_prev.is_empty():
			var final_result_prev: Dictionary = _effect_pipeline_helper.apply_vcam_effect_pipeline(
				previous_vcam_id, pipeline_state_prev, mode_result_prev, landing_offset, delta,
				Callable(self, "_clear_smoothing_state_for_vcam")
			)
			if previous_vcam_id == manager.get_active_vcam_id():
				_write_active_camera_base_fov_from_result(final_result_prev)
			manager.submit_evaluated_camera(previous_vcam_id, final_result_prev)

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
