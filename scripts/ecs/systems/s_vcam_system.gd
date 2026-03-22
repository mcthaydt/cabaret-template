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
const U_VCAM_LOOK_INPUT := preload("res://scripts/ecs/systems/helpers/u_vcam_look_input.gd")
const U_VCAM_ORBIT_EFFECTS := preload("res://scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd")
const U_VCAM_ROTATION := preload("res://scripts/ecs/systems/helpers/u_vcam_rotation.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/utils/math/u_second_order_dynamics_3d.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const C_MOVEMENT_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_CHARACTER_STATE_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_character_state_component.gd")
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
var _follow_dynamics: Dictionary = {}  # StringName -> U_SecondOrderDynamics3D
var _rotation_dynamics: Dictionary = {}  # StringName -> {x, y, z}
var _smoothing_metadata: Dictionary = {}  # StringName -> {mode_script, follow_target_id, response_signature}
var _rotation_target_cache: Dictionary = {}  # StringName -> Vector3 (unwrapped radians)
var _look_input_helper = U_VCAM_LOOK_INPUT.new()
var _debug_issues: Array[String] = []
var _last_active_vcam_id: StringName = StringName("")
var _last_active_target_valid: bool = true
var _last_target_recovery_reason: String = ""
var _last_target_recovery_vcam_id: StringName = StringName("")
var _landing_recovery_dynamics = null
var _landing_recovery_state_id: int = 0
var _landing_recovery_frequency_hz: float = -1.0
var _debug_rotation_log_cooldown_sec: float = 0.0
var _debug_state_log_cooldown_sec: float = 0.0
var _debug_follow_target_ids: Dictionary = {}  # StringName -> int
var _debug_look_ahead_motion_state: Dictionary = {}  # StringName -> bool
var _debug_soft_zone_status: Dictionary = {}  # StringName -> String reason/state
var _debug_landing_offset_status: int = -1  # -1 unknown, 0 inactive, 1 active
var _debug_last_look_input_by_vcam: Dictionary = {}  # StringName -> Vector2
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

func on_configured() -> void:
	_subscribe_events()

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
	_prune_smoothing_state(vcam_index)
	_apply_rotation_continuity_policy(active_vcam_id, vcam_index, manager)

	var look_input: Vector2 = _read_look_input()
	var move_input: Vector2 = _read_move_input()
	var camera_center_just_pressed: bool = _read_camera_center_just_pressed()
	_debug_log_vcam_state("tick", active_vcam_id, look_input)
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
	return _debug_issues.duplicate()

func _exit_tree() -> void:
	_unsubscribe_events()
	_clear_all_smoothing_state()
	_clear_landing_impact_recovery_state()
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
	var component := vcam_index.get(vcam_id, null) as C_VCamComponent
	if component == null or not is_instance_valid(component):
		return

	var mode: Resource = component.mode
	if mode == null:
		return

	var follow_target: Node3D = _resolve_follow_target(component)
	_debug_log_follow_target_resolution(vcam_id, component, follow_target)
	var follow_target_required: bool = _is_follow_target_required(mode)
	if follow_target_required and (follow_target == null or not is_instance_valid(follow_target)):
		_update_active_target_observability(vcam_id, manager, false, "target_freed")
		return

	var response_values: Dictionary = _resolve_component_response_values(component)
	var response_signature: Array[float] = _build_response_signature(response_values)
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
	_debug_log_look_input_transition(vcam_id, filtered_look_input)
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
		return
	_update_active_target_observability(vcam_id, manager, true)
	var look_ahead_result: Dictionary = _apply_orbit_look_ahead(
		vcam_id,
		component,
		mode,
		follow_target,
		result,
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
	var final_result: Dictionary = _apply_landing_impact_offset(smoothed_result, landing_offset)
	if vcam_id == manager.get_active_vcam_id():
		_write_active_camera_base_fov_from_result(final_result)
	manager.submit_evaluated_camera(vcam_id, final_result)

func _apply_landing_impact_offset(result: Dictionary, landing_offset: Vector3) -> Dictionary:
	if landing_offset.is_zero_approx():
		_debug_log_landing_offset_state(landing_offset)
		return result
	_debug_log_landing_offset_state(landing_offset)
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

	var manager_ref: I_ECSManager = get_manager()
	if manager_ref == null:
		return null

	if component.follow_target_entity_id != StringName(""):
		var entity_target: Node = manager_ref.get_entity_by_id(component.follow_target_entity_id)
		var resolved_entity_target: Node3D = _resolve_entity_target(entity_target)
		if resolved_entity_target != null:
			return resolved_entity_target

	if component.follow_target_tag == StringName(""):
		return null

	var tagged_entities: Array[Node] = manager_ref.get_entities_by_tag(component.follow_target_tag)
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
		Callable(self, "_debug_log_look_ahead_motion_state")
	)

func _resolve_look_ahead_movement_velocity(follow_target: Node3D) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var entity: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity != null and is_instance_valid(entity):
		var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity)
		var state_velocity: Dictionary = _read_gameplay_entity_velocity(entity_id)
		if bool(state_velocity.get("has_velocity", false)):
			return state_velocity

		var movement_velocity: Dictionary = _read_entity_movement_component_velocity(entity)
		if bool(movement_velocity.get("has_velocity", false)):
			return movement_velocity

		var body_velocity: Dictionary = _read_entity_character_body_velocity(entity)
		if bool(body_velocity.get("has_velocity", false)):
			return body_velocity

	return _read_character_body_velocity(follow_target)

func _read_gameplay_entity_velocity(entity_id: StringName) -> Dictionary:
	if entity_id == StringName(""):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var store := _resolve_state_store()
	if store == null:
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var gameplay := gameplay_variant as Dictionary

	var entities_variant: Variant = gameplay.get("entities", {})
	if not (entities_variant is Dictionary):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var entities := entities_variant as Dictionary

	var entity_state_variant: Variant = entities.get(String(entity_id), null)
	if not (entity_state_variant is Dictionary):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var entity_state := entity_state_variant as Dictionary
	if not entity_state.has("velocity"):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var velocity_variant: Variant = entity_state.get("velocity", Vector3.ZERO)
	if velocity_variant is Vector3:
		return {
			"has_velocity": true,
			"velocity": velocity_variant as Vector3,
		}
	if velocity_variant is Vector2:
		var velocity_2d := velocity_variant as Vector2
		return {
			"has_velocity": true,
			"velocity": Vector3(velocity_2d.x, 0.0, velocity_2d.y),
		}
	return {"has_velocity": false, "velocity": Vector3.ZERO}

func _read_entity_movement_component_velocity(entity: Node) -> Dictionary:
	var movement_component: Node = _find_node_with_script(entity, C_MOVEMENT_COMPONENT_SCRIPT)
	if movement_component == null:
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	if not movement_component.has_method("get_horizontal_dynamics_velocity"):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var velocity_variant: Variant = movement_component.call("get_horizontal_dynamics_velocity")
	if not (velocity_variant is Vector2):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var velocity_2d := velocity_variant as Vector2
	return {
		"has_velocity": true,
		"velocity": Vector3(velocity_2d.x, 0.0, velocity_2d.y),
	}

func _read_entity_character_body_velocity(entity: Node) -> Dictionary:
	var character_body: CharacterBody3D = _find_character_body_recursive(entity)
	if character_body == null or not is_instance_valid(character_body):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	return {
		"has_velocity": true,
		"velocity": character_body.velocity,
	}

func _read_character_body_velocity(node: Node) -> Dictionary:
	if not (node is CharacterBody3D):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var body := node as CharacterBody3D
	return {
		"has_velocity": true,
		"velocity": body.velocity,
	}

func _find_node_with_script(root: Node, script: Script) -> Node:
	if root == null or script == null:
		return null
	if root.get_script() == script:
		return root

	for child_variant in root.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: Node = _find_node_with_script(child, script)
		if found != null:
			return found
	return null

func _find_character_body_recursive(root: Node) -> CharacterBody3D:
	if root == null:
		return null
	if root is CharacterBody3D:
		return root as CharacterBody3D

	for child_variant in root.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: CharacterBody3D = _find_character_body_recursive(child)
		if found != null and is_instance_valid(found):
			return found
	return null

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
	if follow_target == null or not is_instance_valid(follow_target):
		return false

	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity_root != null and is_instance_valid(entity_root):
		var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
		var state_grounded: Dictionary = _read_gameplay_entity_is_on_floor(entity_id)
		if bool(state_grounded.get("has_value", false)):
			return bool(state_grounded.get("is_on_floor", false))

		var character_state: Node = _find_node_with_script(entity_root, C_CHARACTER_STATE_COMPONENT_SCRIPT)
		if character_state != null and _object_has_property(character_state, "is_grounded"):
			var grounded_variant: Variant = character_state.get("is_grounded")
			if grounded_variant is bool:
				return grounded_variant as bool
			if grounded_variant is int:
				return int(grounded_variant) != 0

	var body: CharacterBody3D = _find_character_body_recursive(follow_target)
	if body == null or not is_instance_valid(body):
		return false
	return body.is_on_floor()

func _read_gameplay_entity_is_on_floor(entity_id: StringName) -> Dictionary:
	if entity_id == StringName(""):
		return {"has_value": false, "is_on_floor": false}

	var store := _resolve_state_store()
	if store == null:
		return {"has_value": false, "is_on_floor": false}

	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		return {"has_value": false, "is_on_floor": false}
	var gameplay := gameplay_variant as Dictionary

	var entities_variant: Variant = gameplay.get("entities", {})
	if not (entities_variant is Dictionary):
		return {"has_value": false, "is_on_floor": false}
	var entities := entities_variant as Dictionary

	var entity_state_variant: Variant = entities.get(String(entity_id), null)
	if not (entity_state_variant is Dictionary):
		return {"has_value": false, "is_on_floor": false}
	var entity_state := entity_state_variant as Dictionary
	if not entity_state.has("is_on_floor"):
		return {"has_value": false, "is_on_floor": false}

	var on_floor_variant: Variant = entity_state.get("is_on_floor", false)
	if on_floor_variant is bool:
		return {"has_value": true, "is_on_floor": on_floor_variant as bool}
	if on_floor_variant is int:
		return {"has_value": true, "is_on_floor": int(on_floor_variant) != 0}
	return {"has_value": false, "is_on_floor": false}

func _probe_ground_reference_height(follow_target: Node3D, max_distance: float) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {"valid": false, "height": 0.0}
	if max_distance <= 0.0:
		return {"valid": false, "height": follow_target.global_position.y}

	var fallback_height: float = follow_target.global_position.y
	var world: World3D = follow_target.get_world_3d()
	if world == null:
		return {"valid": true, "height": fallback_height}
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		return {"valid": true, "height": fallback_height}

	var ray_from: Vector3 = follow_target.global_position + (Vector3.UP * 0.1)
	var ray_to: Vector3 = ray_from + (Vector3.DOWN * max_distance)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	var exclude_rids: Array[RID] = []
	if entity_root != null and is_instance_valid(entity_root):
		var entity_collision := entity_root as CollisionObject3D
		if entity_collision != null:
			exclude_rids.append(entity_collision.get_rid())
	var follow_collision := follow_target as CollisionObject3D
	if follow_collision != null:
		var follow_rid: RID = follow_collision.get_rid()
		if not exclude_rids.has(follow_rid):
			exclude_rids.append(follow_rid)
	if exclude_rids.is_empty():
		var follow_body: CharacterBody3D = _find_character_body_recursive(follow_target)
		if follow_body != null and is_instance_valid(follow_body):
			exclude_rids.append(follow_body.get_rid())
	query.exclude = exclude_rids

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {"valid": true, "height": fallback_height}
	var hit_position_variant: Variant = hit.get("position", Vector3.ZERO)
	if not (hit_position_variant is Vector3):
		return {"valid": true, "height": fallback_height}
	var hit_position := hit_position_variant as Vector3
	return {"valid": true, "height": hit_position.y}

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
		Callable(self, "_debug_log_soft_zone_status"),
		Callable(self, "_debug_log_soft_zone_metrics")
	)

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

func _resolve_component_response_values(component: C_VCamComponent) -> Dictionary:
	if component == null:
		return {}
	var response := component.response as Resource
	if response == null:
		return {}
	if response.get_script() != RS_VCAM_RESPONSE_SCRIPT:
		return {}
	return _resolve_response_values(response)

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

	for stale_id in stale_ids:
		_clear_smoothing_state_for_vcam(stale_id)
		_rotation_helper.clear_centering_state_for_vcam(stale_id)
	_look_input_helper.prune(vcam_index.keys())
	_rotation_helper.prune(vcam_index.keys())
	_orbit_effects_helper.prune(vcam_index.keys())

func _clear_all_smoothing_state() -> void:
	_follow_dynamics.clear()
	_rotation_dynamics.clear()
	_smoothing_metadata.clear()
	_rotation_target_cache.clear()
	_look_input_helper.clear_all()
	_orbit_effects_helper.clear_all()
	_rotation_helper.clear_all()
	_debug_follow_target_ids.clear()
	_debug_look_ahead_motion_state.clear()
	_debug_soft_zone_status.clear()
	_debug_landing_offset_status = -1
	_debug_last_look_input_by_vcam.clear()

func _clear_smoothing_state_for_vcam(vcam_id: StringName) -> void:
	_follow_dynamics.erase(vcam_id)
	_rotation_dynamics.erase(vcam_id)
	_smoothing_metadata.erase(vcam_id)
	_rotation_target_cache.erase(vcam_id)
	_look_input_helper.clear_for_vcam(vcam_id)
	_orbit_effects_helper.clear_for_vcam(vcam_id)
	_rotation_helper.clear_rotation_state_for_vcam(vcam_id)
	_debug_follow_target_ids.erase(vcam_id)
	_debug_look_ahead_motion_state.erase(vcam_id)
	_debug_soft_zone_status.erase(vcam_id)
	_debug_last_look_input_by_vcam.erase(vcam_id)

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
	var follow_target_speed_mps: float = _sample_follow_target_speed(vcam_id, follow_target, delta)
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
	return _step_smoothing_state(
		vcam_id,
		raw_result,
		raw_transform,
		mode_script,
		delta,
		has_active_look_input,
		response_values,
		follow_target_speed_mps
	)

func _step_smoothing_state(
	vcam_id: StringName,
	raw_result: Dictionary,
	raw_transform: Transform3D,
	mode_script: Script,
	delta: float,
	has_active_look_input: bool,
	response_values: Dictionary,
	follow_target_speed_mps: float
) -> Dictionary:
	var follow_dynamics: Variant = _follow_dynamics.get(vcam_id, null)
	if follow_dynamics == null:
		return raw_result

	var bypass_state: Dictionary = _orbit_effects_helper.update_orbit_position_smoothing_bypass(
		vcam_id,
		mode_script,
		RS_VCAM_MODE_ORBIT_SCRIPT,
		has_active_look_input,
		follow_target_speed_mps,
		response_values,
		DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED,
		DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED
	)
	var bypass_non_fixed_position_smoothing: bool = bool(bypass_state.get("bypass", false))
	var bypass_enable_speed: float = float(
		bypass_state.get("enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED)
	)
	var bypass_disable_speed: float = float(
		bypass_state.get("disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)
	)
	var has_previous_bypass_state: bool = bool(
		bypass_state.get("had_previous_bypass_state", false)
	)
	var previous_bypass: bool = bool(bypass_state.get("previous_bypass", false))
	if previous_bypass != bypass_non_fixed_position_smoothing:
		_debug_log_position_smoothing_gate_transition(
			vcam_id,
			mode_script,
			has_active_look_input,
			raw_transform.origin,
			follow_dynamics,
			follow_target_speed_mps,
			bypass_enable_speed,
			bypass_disable_speed,
			previous_bypass,
			bypass_non_fixed_position_smoothing
		)

	# Orbit look input intentionally bypasses follow-position smoothing while rotating.
	# When input is released, reset to current raw position so the first smoothed tick does not pop.
	var released_orbit_bypass_this_tick: bool = (
		has_previous_bypass_state
		and previous_bypass
		and not bypass_non_fixed_position_smoothing
		and mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
	)
	if released_orbit_bypass_this_tick:
		follow_dynamics.reset(raw_transform.origin)
		_debug_log_rotation(
			vcam_id,
			"smoothing_gate_handoff: orbit bypass released, resetting follow dynamics to raw position"
		)
		return raw_result

	if bypass_non_fixed_position_smoothing:
		follow_dynamics.reset(raw_transform.origin)
		return raw_result

	var smooth_position: Vector3 = follow_dynamics.step(raw_transform.origin, delta)
	var smooth_transform := Transform3D(raw_transform.basis.orthonormalized(), smooth_position)
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
			"look_input_deadzone": maxf(
				float(response.get("look_input_deadzone")),
				0.0
			),
			"look_input_hold_sec": maxf(
				float(response.get("look_input_hold_sec")),
				0.0
			),
			"look_input_release_decay": maxf(
				float(response.get("look_input_release_decay")),
				0.0
			),
			"look_release_yaw_damping": maxf(
				float(response.get("look_release_yaw_damping")),
				0.0
			),
			"look_release_pitch_damping": maxf(
				float(response.get("look_release_pitch_damping")),
				0.0
			),
			"look_release_stop_threshold": maxf(
				float(response.get("look_release_stop_threshold")),
				0.0
			),
			"orbit_look_bypass_enable_speed": maxf(
				float(response.get("orbit_look_bypass_enable_speed")),
				0.0
			),
			"orbit_look_bypass_disable_speed": maxf(
				float(response.get("orbit_look_bypass_disable_speed")),
				0.0
			),
			"ground_relative_enabled": bool(response.get("ground_relative_enabled")),
			"ground_reanchor_min_height_delta": maxf(
				float(response.get("ground_reanchor_min_height_delta")),
				0.0
			),
			"ground_probe_max_distance": maxf(
				float(response.get("ground_probe_max_distance")),
				0.0
			),
			"ground_anchor_blend_hz": maxf(
				float(response.get("ground_anchor_blend_hz")),
				0.0
			),
		}
		var resolved_disable_speed: float = maxf(
			float(resolved_values.get("orbit_look_bypass_disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)),
			float(resolved_values.get("orbit_look_bypass_enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED))
		)
		resolved_values["orbit_look_bypass_disable_speed"] = resolved_disable_speed
	return resolved_values

func _build_response_signature(response_values: Dictionary) -> Array[float]:
	return [
		float(response_values.get("follow_frequency", 3.0)),
		float(response_values.get("follow_damping", 0.7)),
		float(response_values.get("follow_initial_response", 1.0)),
		float(response_values.get("rotation_frequency", 4.0)),
		float(response_values.get("rotation_damping", 1.0)),
		float(response_values.get("rotation_initial_response", 1.0)),
		float(response_values.get("look_input_deadzone", U_VCAM_LOOK_INPUT.DEFAULT_LOOK_INPUT_DEADZONE)),
		float(response_values.get("look_input_hold_sec", U_VCAM_LOOK_INPUT.DEFAULT_LOOK_INPUT_HOLD_SEC)),
		float(response_values.get("look_input_release_decay", U_VCAM_LOOK_INPUT.DEFAULT_LOOK_INPUT_RELEASE_DECAY)),
		float(response_values.get("look_release_yaw_damping", DEFAULT_LOOK_RELEASE_YAW_DAMPING)),
		float(response_values.get("look_release_pitch_damping", DEFAULT_LOOK_RELEASE_PITCH_DAMPING)),
		float(response_values.get("look_release_stop_threshold", DEFAULT_LOOK_RELEASE_STOP_THRESHOLD)),
		float(response_values.get("orbit_look_bypass_enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED)),
		float(response_values.get("orbit_look_bypass_disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)),
		1.0 if bool(response_values.get("ground_relative_enabled", false)) else 0.0,
		float(response_values.get("ground_reanchor_min_height_delta", 0.0)),
		float(response_values.get("ground_probe_max_distance", 0.0)),
		float(response_values.get("ground_anchor_blend_hz", 0.0)),
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

func _debug_log_follow_target_resolution(
	vcam_id: StringName,
	component: C_VCamComponent,
	follow_target: Node3D
) -> void:
	if not debug_rotation_logging:
		return
	var target_id: int = _get_node_instance_id(follow_target)
	var previous_target_id: int = int(_debug_follow_target_ids.get(vcam_id, -1))
	if previous_target_id == target_id:
		return
	_debug_follow_target_ids[vcam_id] = target_id

	var resolved_path: String = "<null>"
	if follow_target != null and is_instance_valid(follow_target):
		resolved_path = String(follow_target.get_path())
	var configured_path: String = String(component.follow_target_path)
	var fallback_entity_id: String = String(component.follow_target_entity_id)
	var fallback_tag: String = String(component.follow_target_tag)
	print(
		"S_VCamSystem[debug] follow_target: vcam_id=%s configured_path=%s fallback_entity_id=%s fallback_tag=%s resolved_path=%s resolved_id=%d"
		% [
			String(vcam_id),
			configured_path,
			fallback_entity_id,
			fallback_tag,
			resolved_path,
			target_id,
		]
	)

func _debug_log_look_ahead_motion_state(
	vcam_id: StringName,
	is_moving: bool,
	follow_target: Node3D,
	movement_velocity: Vector3,
	desired_offset: Vector3
) -> void:
	if not debug_rotation_logging:
		return
	var had_state: bool = _debug_look_ahead_motion_state.has(vcam_id)
	var previous_state: bool = bool(_debug_look_ahead_motion_state.get(vcam_id, false))
	_debug_look_ahead_motion_state[vcam_id] = is_moving
	if had_state and previous_state == is_moving:
		return

	var gameplay_is_moving: bool = false
	var gameplay_velocity: Vector3 = Vector3.ZERO
	var gameplay_entity_id: StringName = StringName("")
	if follow_target != null and is_instance_valid(follow_target):
		var entity: Node = U_ECS_UTILS.find_entity_root(follow_target)
		if entity != null and is_instance_valid(entity):
			gameplay_entity_id = U_ECS_UTILS.get_entity_id(entity)
			var store := _resolve_state_store()
			if store != null:
				var state: Dictionary = store.get_state()
				var gameplay_entities: Dictionary = state.get("gameplay", {}).get("entities", {})
				var entity_state: Dictionary = gameplay_entities.get(String(gameplay_entity_id), {})
				if not entity_state.is_empty():
					gameplay_is_moving = bool(entity_state.get("is_moving", false))
					var velocity_variant: Variant = entity_state.get("velocity", Vector3.ZERO)
					if velocity_variant is Vector3:
						gameplay_velocity = velocity_variant as Vector3

	print(
		"S_VCamSystem[debug] look_ahead_motion: vcam_id=%s is_moving=%s movement_speed=%.5f desired_offset_len=%.5f gameplay_entity_id=%s gameplay_is_moving=%s gameplay_velocity=%s"
		% [
			String(vcam_id),
			str(is_moving),
			movement_velocity.length(),
			desired_offset.length(),
			String(gameplay_entity_id),
			str(gameplay_is_moving),
			str(gameplay_velocity),
		]
	)

func _debug_log_soft_zone_status(vcam_id: StringName, status: String, correction: Vector3) -> void:
	if not debug_rotation_logging:
		return
	var previous_status: String = String(_debug_soft_zone_status.get(vcam_id, ""))
	if previous_status == status:
		return
	_debug_soft_zone_status[vcam_id] = status

	print(
		"S_VCamSystem[debug] soft_zone: vcam_id=%s status=%s correction_len=%.5f correction=%s"
		% [
			String(vcam_id),
			status,
			correction.length(),
			str(correction),
		]
	)

func _debug_log_soft_zone_metrics(vcam_id: StringName, correction_result: Dictionary, correction: Vector3) -> void:
	if not debug_rotation_logging:
		return
	var normalized_variant: Variant = correction_result.get("normalized_screen_pos", Vector2.ZERO)
	var corrected_variant: Variant = correction_result.get("corrected_normalized_pos", Vector2.ZERO)
	var dead_zone_variant: Variant = correction_result.get("dead_zone_state", {})
	var normalized_screen_pos: Vector2 = normalized_variant as Vector2 if normalized_variant is Vector2 else Vector2.ZERO
	var corrected_normalized_pos: Vector2 = corrected_variant as Vector2 if corrected_variant is Vector2 else Vector2.ZERO
	var dead_zone_state: Dictionary = dead_zone_variant as Dictionary if dead_zone_variant is Dictionary else {}
	_debug_log_rotation(
		vcam_id,
		"soft_zone_metrics norm=%s corrected=%s correction_len=%.5f dead_zone={x:%s,y:%s}"
		% [
			str(normalized_screen_pos),
			str(corrected_normalized_pos),
			correction.length(),
			str(bool(dead_zone_state.get("x", false))),
			str(bool(dead_zone_state.get("y", false))),
		]
	)

func _debug_log_look_input_transition(vcam_id: StringName, look_input: Vector2) -> void:
	if not debug_rotation_logging:
		return
	var previous_variant: Variant = _debug_last_look_input_by_vcam.get(vcam_id, Vector2.ZERO)
	var previous_input: Vector2 = previous_variant as Vector2 if previous_variant is Vector2 else Vector2.ZERO
	var previously_active: bool = not previous_input.is_zero_approx()
	var currently_active: bool = not look_input.is_zero_approx()

	if previously_active and not currently_active:
		print(
			"S_VCamSystem[debug] look_input_stop: vcam_id=%s previous=%s prev_len=%.5f"
			% [String(vcam_id), str(previous_input), previous_input.length()]
		)
	elif not previously_active and currently_active:
		print(
			"S_VCamSystem[debug] look_input_start: vcam_id=%s current=%s len=%.5f"
			% [String(vcam_id), str(look_input), look_input.length()]
		)
	elif not currently_active and look_input.length_squared() > 0.0:
		_debug_log_rotation(
			vcam_id,
			"look_input_noise raw=%s len=%.6f"
			% [str(look_input), look_input.length()]
		)

	_debug_last_look_input_by_vcam[vcam_id] = look_input

func _debug_log_position_smoothing_gate_transition(
	vcam_id: StringName,
	mode_script: Script,
	has_active_look_input: bool,
	raw_position: Vector3,
	follow_dynamics: Variant,
	follow_target_speed_mps: float,
	enable_speed: float,
	disable_speed: float,
	previous_bypass: bool,
	current_bypass: bool
) -> void:
	if not debug_rotation_logging:
		return
	var cached_position: Vector3 = raw_position
	if follow_dynamics != null and follow_dynamics.has_method("get_value"):
		var cached_variant: Variant = follow_dynamics.call("get_value")
		if cached_variant is Vector3:
			cached_position = cached_variant as Vector3
	var mode_label: String = _get_debug_mode_label(mode_script)
	print(
		"S_VCamSystem[debug] smoothing_gate: vcam_id=%s mode=%s active_input=%s bypass=%s->%s speed=%.4f thresholds=(%.4f,%.4f) raw_pos=%s cached_pos=%s offset_len=%.5f"
		% [
			String(vcam_id),
			mode_label,
			str(has_active_look_input),
			str(previous_bypass),
			str(current_bypass),
			follow_target_speed_mps,
			enable_speed,
			disable_speed,
			str(raw_position),
			str(cached_position),
			raw_position.distance_to(cached_position),
		]
	)

func _get_debug_mode_label(mode_script: Script) -> String:
	if mode_script == null:
		return "<null>"
	var global_name: String = mode_script.get_global_name()
	if not global_name.is_empty():
		return global_name
	var resource_path: String = mode_script.resource_path
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename()
	return "<anonymous>"

func _debug_log_landing_offset_state(landing_offset: Vector3) -> void:
	if not debug_rotation_logging:
		return
	var status: int = 1 if not landing_offset.is_zero_approx() else 0
	if _debug_landing_offset_status == status:
		return
	_debug_landing_offset_status = status
	print(
		"S_VCamSystem[debug] landing_offset: status=%s offset_len=%.5f offset=%s"
		% [
			"active" if status == 1 else "inactive",
			landing_offset.length(),
			str(landing_offset),
			]
		)

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
