@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VCamSystem

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_INPUT_SELECTORS := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const U_VCAM_SOFT_ZONE := preload("res://scripts/managers/helpers/u_vcam_soft_zone.gd")
const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/utils/math/u_second_order_dynamics_3d.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_MODE_FIRST_PERSON_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const RS_VCAM_MODE_FIXED_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")
const RS_VCAM_RESPONSE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")
const RS_VCAM_SOFT_ZONE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")

@export var state_store: I_StateStore = null
@export var vcam_manager: I_VCAM_MANAGER = null
@export var debug_rotation_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_rotation_log_interval_sec: float = 0.25

var _state_store: I_StateStore = null
var _vcam_manager: Node = null
var _path_follow_helpers: Dictionary = {}  # StringName -> PathFollow3D
var _follow_dynamics: Dictionary = {}  # StringName -> U_SecondOrderDynamics3D
var _rotation_dynamics: Dictionary = {}  # StringName -> {x, y, z}
var _smoothing_metadata: Dictionary = {}  # StringName -> {mode_script, follow_target_id, response_signature}
var _look_rotation_state: Dictionary = {}  # StringName -> {smoothed_yaw, smoothed_pitch, yaw_velocity, pitch_velocity, mode_script, follow_target_id, response_signature}
var _rotation_target_cache: Dictionary = {}  # StringName -> Vector3 (unwrapped radians)
var _look_ahead_state: Dictionary = {}  # StringName -> {follow_target_id, last_target_position, current_offset, smoothing_hz, dynamics}
var _orbit_no_look_input_timers: Dictionary = {}  # StringName -> float seconds
var _soft_zone_dead_zone_state: Dictionary = {}  # StringName -> {x: bool, y: bool}
var _debug_issues: Array[String] = []
var _last_active_vcam_id: StringName = StringName("")
var _landing_recovery_dynamics = null
var _landing_recovery_state_id: int = 0
var _landing_recovery_frequency_hz: float = -1.0
var _debug_rotation_log_cooldown_sec: float = 0.0
var _debug_state_log_cooldown_sec: float = 0.0

func process_tick(delta: float) -> void:
	if debug_rotation_logging:
		_debug_rotation_log_cooldown_sec = maxf(_debug_rotation_log_cooldown_sec - maxf(delta, 0.0), 0.0)
		_debug_state_log_cooldown_sec = maxf(_debug_state_log_cooldown_sec - maxf(delta, 0.0), 0.0)
	var manager := _resolve_vcam_manager()
	if manager == null:
		_debug_log_vcam_state("blocked: no vcam_manager service", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var active_vcam_id: StringName = manager.get_active_vcam_id()
	if active_vcam_id == StringName(""):
		_debug_log_vcam_state("blocked: active_vcam_id is empty", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var vcam_index: Dictionary = _build_vcam_index()
	if vcam_index.is_empty():
		_debug_log_vcam_state("blocked: vcam_index is empty", active_vcam_id, Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return
	_prune_path_helpers(vcam_index)
	_prune_smoothing_state(vcam_index)
	_apply_rotation_continuity_policy(active_vcam_id, vcam_index, manager)

	var look_input: Vector2 = _read_look_input()
	_debug_log_vcam_state("tick", active_vcam_id, look_input)
	var landing_offset: Vector3 = _resolve_landing_impact_offset(delta)
	_evaluate_and_submit(active_vcam_id, vcam_index, look_input, landing_offset, manager, delta)

	if not manager.is_blending():
		return

	var previous_vcam_id: StringName = manager.get_previous_vcam_id()
	if previous_vcam_id == StringName("") or previous_vcam_id == active_vcam_id:
		return
	_evaluate_and_submit(previous_vcam_id, vcam_index, look_input, landing_offset, manager, delta)

func get_debug_issues() -> Array[String]:
	return _debug_issues.duplicate()

func _exit_tree() -> void:
	_teardown_path_helpers()
	_clear_all_smoothing_state()
	_clear_landing_impact_recovery_state()
	_look_ahead_state.clear()
	_orbit_no_look_input_timers.clear()
	_soft_zone_dead_zone_state.clear()
	_last_active_vcam_id = StringName("")

func _apply_rotation_continuity_policy(
	active_vcam_id: StringName,
	vcam_index: Dictionary,
	manager: I_VCAM_MANAGER
) -> void:
	if _last_active_vcam_id == active_vcam_id:
		return

	var incoming_component := vcam_index.get(active_vcam_id, null) as C_VCamComponent
	if incoming_component == null or not is_instance_valid(incoming_component):
		_last_active_vcam_id = active_vcam_id
		return

	var outgoing_vcam_id: StringName = manager.get_previous_vcam_id()
	if outgoing_vcam_id == StringName("") or outgoing_vcam_id == active_vcam_id:
		outgoing_vcam_id = _last_active_vcam_id
	if outgoing_vcam_id == StringName("") or outgoing_vcam_id == active_vcam_id:
		_last_active_vcam_id = active_vcam_id
		return

	var outgoing_component := vcam_index.get(outgoing_vcam_id, null) as C_VCamComponent
	if outgoing_component == null or not is_instance_valid(outgoing_component):
		_last_active_vcam_id = active_vcam_id
		return

	_apply_rotation_transition(outgoing_component, incoming_component)
	_last_active_vcam_id = active_vcam_id

func _apply_rotation_transition(outgoing_component: C_VCamComponent, incoming_component: C_VCamComponent) -> void:
	if outgoing_component == null or incoming_component == null:
		return
	if outgoing_component.mode == null or incoming_component.mode == null:
		return

	var outgoing_mode_script := outgoing_component.mode.get_script() as Script
	var incoming_mode_script := incoming_component.mode.get_script() as Script
	if outgoing_mode_script == null or incoming_mode_script == null:
		return

	if outgoing_mode_script == incoming_mode_script:
		_apply_same_mode_rotation_transition(outgoing_component, incoming_component)
		return

	if (
		outgoing_mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
		and incoming_mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT
	):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = 0.0
		return

	if (
		outgoing_mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT
		and incoming_mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
	):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = 0.0
		return

	if (
		outgoing_mode_script == RS_VCAM_MODE_FIXED_SCRIPT
		and (
			incoming_mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
			or incoming_mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT
		)
	):
		var authored_angles: Vector2 = _resolve_authored_rotation(incoming_component.mode)
		incoming_component.runtime_yaw = authored_angles.x
		incoming_component.runtime_pitch = 0.0

func _apply_same_mode_rotation_transition(
	outgoing_component: C_VCamComponent,
	incoming_component: C_VCamComponent
) -> void:
	if _components_share_follow_target(outgoing_component, incoming_component):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = outgoing_component.runtime_pitch
		return

	var authored_angles: Vector2 = _resolve_authored_rotation(incoming_component.mode)
	incoming_component.runtime_yaw = authored_angles.x
	incoming_component.runtime_pitch = authored_angles.y

func _components_share_follow_target(
	outgoing_component: C_VCamComponent,
	incoming_component: C_VCamComponent
) -> bool:
	if outgoing_component == null or incoming_component == null:
		return false

	var outgoing_target: Node3D = _resolve_follow_target(outgoing_component)
	var incoming_target: Node3D = _resolve_follow_target(incoming_component)
	if outgoing_target == null or incoming_target == null:
		return false
	return _get_node_instance_id(outgoing_target) == _get_node_instance_id(incoming_target)

func _resolve_authored_rotation(mode: Resource) -> Vector2:
	if mode == null:
		return Vector2.ZERO

	var mode_script := mode.get_script() as Script
	if mode_script == RS_VCAM_MODE_ORBIT_SCRIPT:
		var orbit_values: Dictionary = _resolve_mode_values(mode, {
			"authored_yaw": 0.0,
			"authored_pitch": 0.0,
		})
		return Vector2(
			float(orbit_values.get("authored_yaw", 0.0)),
			float(orbit_values.get("authored_pitch", 0.0))
		)

	return Vector2.ZERO

func _evaluate_and_submit(
	vcam_id: StringName,
	vcam_index: Dictionary,
	look_input: Vector2,
	landing_offset: Vector3,
	manager: I_VCAM_MANAGER,
	delta: float
) -> void:
	var component := vcam_index.get(vcam_id, null) as C_VCamComponent
	if component == null or not is_instance_valid(component):
		return

	var mode: Resource = component.mode
	if mode == null:
		return

	var follow_target: Node3D = _resolve_follow_target(component)
	var fixed_anchor: Node3D = component.get_fixed_anchor()
	if _is_path_fixed_mode(mode):
		fixed_anchor = _resolve_or_create_path_anchor(component, follow_target)
		if fixed_anchor == null:
			return

	_update_runtime_rotation(vcam_id, component, mode, look_input, delta)
	var response_values: Dictionary = _resolve_component_response_values(component)
	var runtime_rotation: Vector2 = _resolve_runtime_rotation_for_evaluation(
		vcam_id,
		component,
		mode,
		follow_target,
		response_values,
		delta
	)
	var look_at_target: Node3D = component.get_look_at_target()
	var result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		look_at_target,
		runtime_rotation.x,
		runtime_rotation.y,
		fixed_anchor
	)
	if result.is_empty():
		return
	var look_ahead_result: Dictionary = _apply_orbit_look_ahead(
		vcam_id,
		component,
		mode,
		follow_target,
		result,
		delta
	)
	var soft_zone_result: Dictionary = _apply_orbit_soft_zone(
		vcam_id,
		component,
		mode,
		follow_target,
		look_ahead_result,
		delta
	)
	var smoothed_result: Dictionary = _apply_response_smoothing(
		vcam_id,
		component,
		mode,
		follow_target,
		soft_zone_result,
		delta
	)
	var final_result: Dictionary = _apply_landing_impact_offset(smoothed_result, landing_offset)
	if vcam_id == manager.get_active_vcam_id():
		_write_active_camera_base_fov_from_result(final_result)
	manager.submit_evaluated_camera(vcam_id, final_result)

func _apply_landing_impact_offset(result: Dictionary, landing_offset: Vector3) -> Dictionary:
	if landing_offset.is_zero_approx():
		return result
	return _apply_position_offset(result, landing_offset)

func _resolve_landing_impact_offset(delta: float) -> Vector3:
	var camera_state: Object = _resolve_primary_camera_state_component()
	if camera_state == null:
		_clear_landing_impact_recovery_state()
		return Vector3.ZERO

	var current_offset: Vector3 = _read_camera_state_vector3(camera_state, "landing_impact_offset", Vector3.ZERO)
	if current_offset.is_zero_approx():
		_clear_landing_impact_recovery_state()
		return Vector3.ZERO

	var recovery_speed_hz: float = maxf(
		_get_camera_state_float(
			camera_state,
			"landing_impact_recovery_speed",
			C_CAMERA_STATE_COMPONENT.DEFAULT_LANDING_IMPACT_RECOVERY_SPEED
		),
		0.0
	)
	if recovery_speed_hz <= 0.0:
		_clear_landing_impact_recovery_state()
		return current_offset

	var camera_state_id: int = camera_state.get_instance_id()
	var needs_rebuild: bool = (
		_landing_recovery_dynamics == null
		or _landing_recovery_state_id != camera_state_id
		or not is_equal_approx(_landing_recovery_frequency_hz, recovery_speed_hz)
	)
	if needs_rebuild:
		_landing_recovery_dynamics = U_SECOND_ORDER_DYNAMICS_3D.new(
			recovery_speed_hz,
			1.0,
			1.0,
			current_offset
		)
		_landing_recovery_state_id = camera_state_id
		_landing_recovery_frequency_hz = recovery_speed_hz
		if delta <= 0.0:
			return current_offset

	var recovered_offset: Vector3 = _landing_recovery_dynamics.step(Vector3.ZERO, delta)
	if recovered_offset.length_squared() <= 0.000001:
		recovered_offset = Vector3.ZERO
		_clear_landing_impact_recovery_state()

	_write_camera_state_vector3(camera_state, "landing_impact_offset", recovered_offset)
	return recovered_offset

func _clear_landing_impact_recovery_state() -> void:
	_landing_recovery_dynamics = null
	_landing_recovery_state_id = 0
	_landing_recovery_frequency_hz = -1.0

func _resolve_primary_camera_state_component() -> Object:
	var queries: Array = query_entities([CAMERA_STATE_TYPE])
	var fallback: Object = null
	for query_variant in queries:
		if query_variant == null or not (query_variant is Object):
			continue
		var query: Object = query_variant as Object
		if not query.has_method("get_component"):
			continue
		var camera_state_variant: Variant = query.call("get_component", CAMERA_STATE_TYPE)
		if not (camera_state_variant is Object):
			continue
		var camera_state: Object = camera_state_variant as Object
		if fallback == null:
			fallback = camera_state
		if _is_primary_camera_query(query):
			return camera_state
	return fallback

func _write_active_camera_base_fov_from_result(result: Dictionary) -> void:
	if result.is_empty():
		return

	var fov_variant: Variant = result.get("fov", null)
	if not (fov_variant is float or fov_variant is int):
		return

	var fov_value: float = float(fov_variant)
	if is_nan(fov_value) or is_inf(fov_value):
		return

	var camera_state: Object = _resolve_primary_camera_state_component()
	if camera_state == null:
		return
	if not _object_has_property(camera_state, "base_fov"):
		return

	camera_state.set("base_fov", clampf(fov_value, 1.0, 179.0))

func _is_primary_camera_query(query: Object) -> bool:
	if query.has_method("get_entity_id"):
		var entity_id: StringName = _variant_to_string_name(query.call("get_entity_id"))
		if entity_id == PRIMARY_CAMERA_ENTITY_ID:
			return true
	if query.has_method("get_tags"):
		var tags_variant: Variant = query.call("get_tags")
		if tags_variant is Array:
			var tags: Array = tags_variant as Array
			return tags.has(PRIMARY_CAMERA_ENTITY_ID) or tags.has(String(PRIMARY_CAMERA_ENTITY_ID))
	return false

func _get_camera_state_float(camera_state: Object, property_name: String, fallback: float) -> float:
	if camera_state == null:
		return fallback
	if not _object_has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _read_camera_state_vector3(camera_state: Object, property_name: String, fallback: Vector3) -> Vector3:
	if camera_state == null:
		return fallback
	if not _object_has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is Vector3:
		return value as Vector3
	return fallback

func _write_camera_state_vector3(camera_state: Object, property_name: String, value: Vector3) -> void:
	if camera_state == null:
		return
	if not _object_has_property(camera_state, property_name):
		return
	camera_state.set(property_name, value)

func _object_has_property(object_value: Object, property_name: String) -> bool:
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_variant: Variant = property_info.get("name", "")
		if str(name_variant) == property_name:
			return true
	return false

func _variant_to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	if value is String:
		var text: String = value
		if text.is_empty():
			return StringName("")
		return StringName(text)
	return StringName("")

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
	if component == null:
		return null

	var node_target: Node3D = component.get_follow_target()
	if node_target != null and is_instance_valid(node_target):
		return node_target

	var ecs_manager: I_ECSManager = get_manager()
	if ecs_manager == null:
		return null

	if component.follow_target_entity_id != StringName(""):
		var entity_target: Node = ecs_manager.get_entity_by_id(component.follow_target_entity_id)
		var resolved_entity_target: Node3D = _resolve_entity_target(entity_target)
		if resolved_entity_target != null:
			return resolved_entity_target

	if component.follow_target_tag == StringName(""):
		return null

	var tagged_entities: Array[Node] = ecs_manager.get_entities_by_tag(component.follow_target_tag)
	if tagged_entities.is_empty():
		return null

	var valid_targets: Array[Node3D] = []
	for entity in tagged_entities:
		var resolved: Node3D = _resolve_entity_target(entity)
		if resolved == null:
			continue
		valid_targets.append(resolved)

	if valid_targets.is_empty():
		return null
	if valid_targets.size() > 1:
		_report_issue(
			"follow_target_tag '%s' resolved multiple entities; using first match" % String(component.follow_target_tag)
		)
	return valid_targets[0]

func _resolve_entity_target(entity: Node) -> Node3D:
	if entity == null or not is_instance_valid(entity):
		return null
	if entity is Node3D:
		return entity as Node3D
	var body_target := entity.get_node_or_null("Body") as Node3D
	if body_target != null and is_instance_valid(body_target):
		return body_target
	return null

func _update_runtime_rotation(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	look_input: Vector2,
	delta: float
) -> void:
	if component == null or mode == null:
		return

	var mode_script := mode.get_script() as Script
	var has_look_input: bool = not look_input.is_zero_approx()
	if mode_script == RS_VCAM_MODE_ORBIT_SCRIPT:
		var orbit_values: Dictionary = _resolve_mode_values(mode, {
			"allow_player_rotation": true,
			"lock_x_rotation": false,
			"lock_y_rotation": true,
			"rotation_speed": 0.0,
		})
		if not bool(orbit_values.get("allow_player_rotation", true)):
			_orbit_no_look_input_timers.erase(vcam_id)
			return

		var lock_x_rotation: bool = bool(orbit_values.get("lock_x_rotation", false))
		var lock_y_rotation: bool = bool(orbit_values.get("lock_y_rotation", true))
		if lock_x_rotation:
			component.runtime_yaw = 0.0
		if lock_y_rotation:
			component.runtime_pitch = 0.0

		var rotation_speed: float = maxf(float(orbit_values.get("rotation_speed", 0.0)), 0.0)
		if has_look_input:
			var previous_yaw: float = component.runtime_yaw
			var previous_pitch: float = component.runtime_pitch
			if not lock_x_rotation:
				component.runtime_yaw += look_input.x * rotation_speed
			if not lock_y_rotation:
				component.runtime_pitch += look_input.y * rotation_speed
			_debug_log_rotation(
				vcam_id,
				"orbit input=%s allow=%s lock_x=%s lock_y=%s speed=%.3f yaw=%.3f->%.3f pitch=%.3f->%.3f"
				% [
					str(look_input),
					str(bool(orbit_values.get("allow_player_rotation", true))),
					str(lock_x_rotation),
					str(lock_y_rotation),
					rotation_speed,
					previous_yaw,
					component.runtime_yaw,
					previous_pitch,
					component.runtime_pitch,
				]
			)
			_orbit_no_look_input_timers[vcam_id] = 0.0
			return
		if lock_y_rotation:
			_orbit_no_look_input_timers.erase(vcam_id)
			return

		var no_look_timer: float = float(_orbit_no_look_input_timers.get(vcam_id, 0.0))
		no_look_timer += maxf(delta, 0.0)
		_orbit_no_look_input_timers[vcam_id] = no_look_timer

		var response_values: Dictionary = _resolve_component_response_values(component)
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
		return

	_orbit_no_look_input_timers.erase(vcam_id)
	if not has_look_input:
		return
	if mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT:
		var first_person_values: Dictionary = _resolve_mode_values(mode, {
			"look_multiplier": 1.0,
		})
		var look_multiplier: float = maxf(float(first_person_values.get("look_multiplier", 1.0)), 0.0001)
		var previous_fp_yaw: float = component.runtime_yaw
		var previous_fp_pitch: float = component.runtime_pitch
		component.runtime_yaw += look_input.x * look_multiplier
		component.runtime_pitch += look_input.y * look_multiplier
		_debug_log_rotation(
			vcam_id,
			"first_person input=%s multiplier=%.3f yaw=%.3f->%.3f pitch=%.3f->%.3f"
			% [
				str(look_input),
				look_multiplier,
				previous_fp_yaw,
				component.runtime_yaw,
				previous_fp_pitch,
				component.runtime_pitch,
			]
		)

func _apply_orbit_look_ahead(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	delta: float
) -> Dictionary:
	if component == null or mode == null:
		return result
	if mode.get_script() != RS_VCAM_MODE_ORBIT_SCRIPT:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var response_values: Dictionary = _resolve_component_response_values(component)
	var look_ahead_distance: float = maxf(float(response_values.get("look_ahead_distance", 0.0)), 0.0)
	if look_ahead_distance <= 0.0:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var target_id: int = _get_node_instance_id(follow_target)
	if target_id == 0:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var current_position: Vector3 = follow_target.global_position
	var state: Dictionary = _get_or_create_look_ahead_state(vcam_id, target_id, current_position)
	var previous_position: Vector3 = state.get("last_target_position", current_position) as Vector3
	state["last_target_position"] = current_position

	var velocity: Vector3 = Vector3.ZERO
	if delta > 0.0:
		velocity = (current_position - previous_position) / delta
	var desired_offset: Vector3 = Vector3.ZERO
	if velocity.length_squared() > 0.000001:
		desired_offset = velocity.normalized() * look_ahead_distance

	var smoothing_hz: float = maxf(float(response_values.get("look_ahead_smoothing", 3.0)), 0.0)
	var current_offset: Vector3 = state.get("current_offset", Vector3.ZERO) as Vector3
	var smoothed_offset: Vector3 = desired_offset
	if smoothing_hz > 0.0:
		var rebuild_dynamics: bool = (
			not state.has("dynamics")
			or state.get("dynamics", null) == null
			or not is_equal_approx(float(state.get("smoothing_hz", -1.0)), smoothing_hz)
		)
		if rebuild_dynamics:
			state["dynamics"] = U_SECOND_ORDER_DYNAMICS_3D.new(smoothing_hz, 1.0, 0.0, current_offset)
			state["smoothing_hz"] = smoothing_hz
		var dynamics = state.get("dynamics", null)
		if dynamics != null:
			smoothed_offset = dynamics.step(desired_offset, maxf(delta, 0.0))
	else:
		state["dynamics"] = null
		state["smoothing_hz"] = 0.0

	if smoothed_offset.length_squared() > (look_ahead_distance * look_ahead_distance):
		smoothed_offset = smoothed_offset.normalized() * look_ahead_distance

	state["current_offset"] = smoothed_offset
	_look_ahead_state[vcam_id] = state

	if smoothed_offset.is_zero_approx():
		return result
	return _apply_position_offset(result, smoothed_offset)

func _get_or_create_look_ahead_state(
	vcam_id: StringName,
	follow_target_id: int,
	current_position: Vector3
) -> Dictionary:
	var state_variant: Variant = _look_ahead_state.get(vcam_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = (state_variant as Dictionary).duplicate(true)

	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if state.is_empty() or previous_target_id != follow_target_id:
		state = {
			"follow_target_id": follow_target_id,
			"last_target_position": current_position,
			"current_offset": Vector3.ZERO,
			"smoothing_hz": -1.0,
			"dynamics": null,
		}
		_look_ahead_state[vcam_id] = state
	return state

func _clear_look_ahead_state_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_state.erase(vcam_id)

func _apply_orbit_soft_zone(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	delta: float
) -> Dictionary:
	if component == null or mode == null:
		return result
	if mode.get_script() != RS_VCAM_MODE_ORBIT_SCRIPT:
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		return result
	if component.soft_zone == null:
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		return result
	if component.soft_zone.get_script() != RS_VCAM_SOFT_ZONE_SCRIPT:
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result
	var desired_transform := transform_variant as Transform3D

	var projection_camera: Camera3D = _resolve_projection_camera()
	if projection_camera == null:
		return result

	var dead_zone_state: Dictionary = _get_soft_zone_dead_zone_state(vcam_id)
	var correction_result: Dictionary = U_VCAM_SOFT_ZONE.compute_camera_correction_with_state(
		projection_camera,
		follow_target.global_position,
		desired_transform,
		component.soft_zone as Resource,
		delta,
		dead_zone_state
	)
	var next_state_variant: Variant = correction_result.get("dead_zone_state", dead_zone_state)
	if next_state_variant is Dictionary:
		_soft_zone_dead_zone_state[vcam_id] = (next_state_variant as Dictionary).duplicate(true)
	var correction_variant: Variant = correction_result.get("correction", Vector3.ZERO)
	if not (correction_variant is Vector3):
		return result
	var correction := correction_variant as Vector3
	if correction.is_zero_approx():
		return result
	return _apply_position_offset(result, correction)

func _resolve_projection_camera() -> Camera3D:
	var camera_manager_service := U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager")) as I_CAMERA_MANAGER
	if camera_manager_service != null and is_instance_valid(camera_manager_service):
		var main_camera: Camera3D = camera_manager_service.get_main_camera()
		if main_camera != null and is_instance_valid(main_camera):
			return main_camera

	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var viewport_camera: Camera3D = viewport.get_camera_3d()
	if viewport_camera == null or not is_instance_valid(viewport_camera):
		return null
	return viewport_camera

func _get_soft_zone_dead_zone_state(vcam_id: StringName) -> Dictionary:
	var state_variant: Variant = _soft_zone_dead_zone_state.get(vcam_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {
		"x": false,
		"y": false,
	}

func _clear_soft_zone_dead_zone_state_for_vcam(vcam_id: StringName) -> void:
	_soft_zone_dead_zone_state.erase(vcam_id)

func _resolve_component_response_values(component: C_VCamComponent) -> Dictionary:
	if component == null:
		return {}
	var response := component.response as Resource
	if response == null:
		return {}
	if response.get_script() != RS_VCAM_RESPONSE_SCRIPT:
		return {}
	return _resolve_response_values(response)

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

func _is_path_fixed_mode(mode: Resource) -> bool:
	if mode == null:
		return false
	var mode_script := mode.get_script() as Script
	if mode_script != RS_VCAM_MODE_FIXED_SCRIPT:
		return false
	var fixed_values: Dictionary = _resolve_mode_values(mode, {"use_path": false})
	return bool(fixed_values.get("use_path", false))

func _resolve_or_create_path_anchor(component: C_VCamComponent, follow_target: Node3D) -> Node3D:
	if component == null:
		return null

	var path_node: Path3D = component.get_path_node()
	if path_node == null or not is_instance_valid(path_node):
		return null

	var vcam_id: StringName = _resolve_component_vcam_id(component)
	if vcam_id == StringName(""):
		return null

	var helper := _path_follow_helpers.get(vcam_id, null) as PathFollow3D
	if helper == null or not is_instance_valid(helper):
		helper = PathFollow3D.new()
		helper.name = "PathFollow_%s" % String(vcam_id)
		path_node.add_child(helper)
		_path_follow_helpers[vcam_id] = helper
	elif helper.get_parent() != path_node:
		if helper.get_parent() != null:
			helper.get_parent().remove_child(helper)
		path_node.add_child(helper)

	if follow_target == null or not is_instance_valid(follow_target):
		return null
	if path_node.curve == null:
		return null

	var local_target_position: Vector3 = path_node.to_local(follow_target.global_position)
	helper.progress = path_node.curve.get_closest_offset(local_target_position)
	return helper

func _prune_path_helpers(vcam_index: Dictionary) -> void:
	var stale_ids: Array[StringName] = []
	for vcam_id_variant in _path_follow_helpers.keys():
		var vcam_id := vcam_id_variant as StringName
		var helper := _path_follow_helpers.get(vcam_id, null) as PathFollow3D
		if helper == null or not is_instance_valid(helper):
			stale_ids.append(vcam_id)
			continue
		if not vcam_index.has(vcam_id):
			stale_ids.append(vcam_id)
			helper.queue_free()
			continue

	for stale_id in stale_ids:
		_path_follow_helpers.erase(stale_id)

func _prune_smoothing_state(vcam_index: Dictionary) -> void:
	var stale_ids: Array[StringName] = []

	for vcam_id_variant in _follow_dynamics.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _rotation_dynamics.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _smoothing_metadata.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _look_ahead_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _orbit_no_look_input_timers.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _soft_zone_dead_zone_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _look_rotation_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		_clear_smoothing_state_for_vcam(stale_id)
		_clear_soft_zone_dead_zone_state_for_vcam(stale_id)

func _teardown_path_helpers() -> void:
	for helper_variant in _path_follow_helpers.values():
		var helper := helper_variant as PathFollow3D
		if helper == null or not is_instance_valid(helper):
			continue
		helper.queue_free()
	_path_follow_helpers.clear()

func _clear_all_smoothing_state() -> void:
	_follow_dynamics.clear()
	_rotation_dynamics.clear()
	_smoothing_metadata.clear()
	_look_rotation_state.clear()
	_rotation_target_cache.clear()
	_look_ahead_state.clear()
	_orbit_no_look_input_timers.clear()

func _clear_smoothing_state_for_vcam(vcam_id: StringName) -> void:
	_follow_dynamics.erase(vcam_id)
	_rotation_dynamics.erase(vcam_id)
	_smoothing_metadata.erase(vcam_id)
	_look_rotation_state.erase(vcam_id)
	_rotation_target_cache.erase(vcam_id)
	_look_ahead_state.erase(vcam_id)
	_orbit_no_look_input_timers.erase(vcam_id)

func _resolve_runtime_rotation_for_evaluation(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	response_values: Dictionary,
	delta: float
) -> Vector2:
	if component == null or mode == null:
		return Vector2.ZERO

	var target_rotation := Vector2(component.runtime_yaw, component.runtime_pitch)
	var mode_script := mode.get_script() as Script
	if not _is_look_rotation_smoothing_mode(mode_script):
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
	var response_signature: Array[float] = _build_response_signature(response_values)
	var state: Dictionary = _get_look_rotation_state(vcam_id)
	if (
		state.is_empty()
		or _did_mode_change(state, mode_script)
		or _did_follow_target_change(state, follow_target_id)
		or _did_response_change(state, response_signature)
	):
		_set_look_rotation_state(vcam_id, target_rotation, Vector2.ZERO, mode_script, follow_target_id, response_signature)
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
		response_signature
	)
	return smoothed_rotation

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

func _is_look_rotation_smoothing_mode(mode_script: Script) -> bool:
	return mode_script == RS_VCAM_MODE_ORBIT_SCRIPT or mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT

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
	response_signature: Array[float]
) -> void:
	_look_rotation_state[vcam_id] = {
		"smoothed_yaw": smoothed_rotation.x,
		"smoothed_pitch": smoothed_rotation.y,
		"yaw_velocity": rotation_velocity.x,
		"pitch_velocity": rotation_velocity.y,
		"mode_script": mode_script,
		"follow_target_id": follow_target_id,
		"response_signature": response_signature.duplicate(),
	}

func _clear_look_rotation_state_for_vcam(vcam_id: StringName) -> void:
	_look_rotation_state.erase(vcam_id)

func _apply_response_smoothing(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	raw_result: Dictionary,
	delta: float
) -> Dictionary:
	if component == null:
		return raw_result
	if mode == null:
		return raw_result

	var raw_transform_variant: Variant = raw_result.get("transform", null)
	if not (raw_transform_variant is Transform3D):
		return raw_result
	var raw_transform := raw_transform_variant as Transform3D

	var response := component.response as Resource
	if response == null:
		_clear_smoothing_state_for_vcam(vcam_id)
		return raw_result
	if response.get_script() != RS_VCAM_RESPONSE_SCRIPT:
		_clear_smoothing_state_for_vcam(vcam_id)
		return raw_result

	var response_values: Dictionary = _resolve_response_values(response)
	var response_signature: Array[float] = _build_response_signature(response_values)
	var mode_script := mode.get_script() as Script
	var follow_target_id: int = _get_node_instance_id(follow_target)
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
	return _step_smoothing_state(vcam_id, raw_result, raw_transform, target_euler, mode_script, delta)

func _step_smoothing_state(
	vcam_id: StringName,
	raw_result: Dictionary,
	raw_transform: Transform3D,
	target_euler: Vector3,
	mode_script: Script,
	delta: float
) -> Dictionary:
	var follow_dynamics: Variant = _follow_dynamics.get(vcam_id, null)
	if follow_dynamics == null:
		return raw_result

	var rotation_entry_variant: Variant = _rotation_dynamics.get(vcam_id, {})
	if not (rotation_entry_variant is Dictionary):
		return raw_result
	var rotation_entry := rotation_entry_variant as Dictionary

	var smooth_position: Vector3 = follow_dynamics.step(raw_transform.origin, delta)
	if mode_script != RS_VCAM_MODE_FIXED_SCRIPT:
		var smooth_transform_non_fixed := Transform3D(raw_transform.basis.orthonormalized(), smooth_position)
		var non_fixed_result: Dictionary = raw_result.duplicate(true)
		non_fixed_result["transform"] = smooth_transform_non_fixed
		return non_fixed_result

	var smooth_x: float = _step_rotation_axis(rotation_entry, StringName("x"), target_euler.x, delta)
	var smooth_y: float = _step_rotation_axis(rotation_entry, StringName("y"), target_euler.y, delta)
	var smooth_z: float = _step_rotation_axis(rotation_entry, StringName("z"), target_euler.z, delta)
	var smooth_basis: Basis = _compose_basis_from_euler(Vector3(smooth_x, smooth_y, smooth_z))

	var smooth_transform := Transform3D(smooth_basis, smooth_position)
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

func _step_rotation_axis(rotation_entry: Dictionary, key: StringName, target: float, delta: float) -> float:
	var axis_dynamics: Variant = rotation_entry.get(key, null)
	if axis_dynamics == null:
		return target
	return float(axis_dynamics.step(target, delta))

func _reset_rotation_axis(rotation_entry: Dictionary, key: StringName, value: float) -> void:
	var axis_dynamics: Variant = rotation_entry.get(key, null)
	if axis_dynamics == null:
		return
	axis_dynamics.reset(value)

func _resolve_response_values(response: Resource) -> Dictionary:
	var resolved_values: Dictionary = {}
	if response.has_method("get_resolved_values"):
		var resolved_variant: Variant = response.call("get_resolved_values")
		if resolved_variant is Dictionary:
			resolved_values = (resolved_variant as Dictionary).duplicate(true)

	if resolved_values.is_empty():
		resolved_values = {
			"follow_frequency": maxf(float(response.get("follow_frequency")), 0.0001),
			"follow_damping": maxf(float(response.get("follow_damping")), 0.0),
			"follow_initial_response": float(response.get("follow_initial_response")),
			"rotation_frequency": maxf(float(response.get("rotation_frequency")), 0.0001),
			"rotation_damping": maxf(float(response.get("rotation_damping")), 0.0),
			"rotation_initial_response": float(response.get("rotation_initial_response")),
			"look_ahead_distance": maxf(float(response.get("look_ahead_distance")), 0.0),
			"look_ahead_smoothing": maxf(float(response.get("look_ahead_smoothing")), 0.0),
			"auto_level_speed": maxf(float(response.get("auto_level_speed")), 0.0),
			"auto_level_delay": maxf(float(response.get("auto_level_delay")), 0.0),
		}
	return resolved_values

func _build_response_signature(response_values: Dictionary) -> Array[float]:
	return [
		float(response_values.get("follow_frequency", 3.0)),
		float(response_values.get("follow_damping", 0.7)),
		float(response_values.get("follow_initial_response", 1.0)),
		float(response_values.get("rotation_frequency", 4.0)),
		float(response_values.get("rotation_damping", 1.0)),
		float(response_values.get("rotation_initial_response", 1.0)),
	]

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

func _get_node_instance_id(node: Node) -> int:
	if node == null:
		return 0
	if not is_instance_valid(node):
		return 0
	return node.get_instance_id()

func _compose_basis_from_euler(euler: Vector3) -> Basis:
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, euler.y)
	basis = basis.rotated(basis.x, euler.x)
	basis = basis.rotated(basis.z, euler.z)
	return basis.orthonormalized()

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

func _report_issue(message: String) -> void:
	if _debug_issues.size() >= 64:
		_debug_issues.remove_at(0)
	_debug_issues.append(message)
	print_verbose("S_VCamSystem: %s" % message)

func _debug_log_rotation(vcam_id: StringName, message: String) -> void:
	if not debug_rotation_logging:
		return
	if _debug_rotation_log_cooldown_sec > 0.0:
		return
	var interval: float = maxf(debug_rotation_log_interval_sec, 0.05)
	_debug_rotation_log_cooldown_sec = interval
	print("S_VCamSystem[debug] %s: %s" % [str(vcam_id), message])

func _debug_log_vcam_state(message: String, active_vcam_id: StringName, look_input: Vector2) -> void:
	if not debug_rotation_logging:
		return
	if _debug_state_log_cooldown_sec > 0.0:
		return
	var interval: float = maxf(debug_rotation_log_interval_sec, 0.05)
	_debug_state_log_cooldown_sec = interval
	print(
		"S_VCamSystem[debug] state: %s active_vcam_id=%s look_input=%s"
		% [message, str(active_vcam_id), str(look_input)]
	)
