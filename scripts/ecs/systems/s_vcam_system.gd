@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VCamSystem

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_INPUT_SELECTORS := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_MODE_FIRST_PERSON_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const RS_VCAM_MODE_FIXED_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")

@export var state_store: I_StateStore = null
@export var vcam_manager: I_VCAM_MANAGER = null

var _state_store: I_StateStore = null
var _vcam_manager: Node = null
var _path_follow_helpers: Dictionary = {}  # StringName -> PathFollow3D
var _debug_issues: Array[String] = []

func process_tick(_delta: float) -> void:
	var manager := _resolve_vcam_manager()
	if manager == null:
		return

	var active_vcam_id: StringName = manager.get_active_vcam_id()
	if active_vcam_id == StringName(""):
		return

	var vcam_index: Dictionary = _build_vcam_index()
	if vcam_index.is_empty():
		return
	_prune_path_helpers(vcam_index)

	var look_input: Vector2 = _read_look_input()
	_evaluate_and_submit(active_vcam_id, vcam_index, look_input, manager)

	if not manager.is_blending():
		return

	var previous_vcam_id: StringName = manager.get_previous_vcam_id()
	if previous_vcam_id == StringName("") or previous_vcam_id == active_vcam_id:
		return
	_evaluate_and_submit(previous_vcam_id, vcam_index, look_input, manager)

func get_debug_issues() -> Array[String]:
	return _debug_issues.duplicate()

func _exit_tree() -> void:
	_teardown_path_helpers()

func _evaluate_and_submit(
	vcam_id: StringName,
	vcam_index: Dictionary,
	look_input: Vector2,
	manager: I_VCAM_MANAGER
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

	_update_runtime_rotation(component, mode, look_input)
	var look_at_target: Node3D = component.get_look_at_target()
	var result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		look_at_target,
		component.runtime_yaw,
		component.runtime_pitch,
		fixed_anchor
	)
	if result.is_empty():
		return
	manager.submit_evaluated_camera(vcam_id, result)

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

func _update_runtime_rotation(component: C_VCamComponent, mode: Resource, look_input: Vector2) -> void:
	if component == null or mode == null:
		return
	if look_input == Vector2.ZERO:
		return

	var mode_script := mode.get_script() as Script
	if mode_script == RS_VCAM_MODE_ORBIT_SCRIPT:
		var orbit_values: Dictionary = _resolve_mode_values(mode, {
			"allow_player_rotation": true,
			"rotation_speed": 0.0,
		})
		if not bool(orbit_values.get("allow_player_rotation", true)):
			return
		var rotation_speed: float = maxf(float(orbit_values.get("rotation_speed", 0.0)), 0.0)
		component.runtime_yaw += look_input.x * rotation_speed
		component.runtime_pitch += look_input.y * rotation_speed
		return

	if mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT:
		var first_person_values: Dictionary = _resolve_mode_values(mode, {
			"look_multiplier": 1.0,
		})
		var look_multiplier: float = maxf(float(first_person_values.get("look_multiplier", 1.0)), 0.0001)
		component.runtime_yaw += look_input.x * look_multiplier
		component.runtime_pitch += look_input.y * look_multiplier

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

func _teardown_path_helpers() -> void:
	for helper_variant in _path_follow_helpers.values():
		var helper := helper_variant as PathFollow3D
		if helper == null or not is_instance_valid(helper):
			continue
		helper.queue_free()
	_path_follow_helpers.clear()

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
