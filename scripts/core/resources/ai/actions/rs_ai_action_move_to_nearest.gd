@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionMoveToNearest

const DETECTION_COMPONENT_TYPE := StringName("C_DetectionComponent")
const MOVE_TARGET_COMPONENT_TYPE := StringName("C_MoveTargetComponent")
const BUILD_SITE_COMPONENT_TYPE := StringName("C_BuildSiteComponent")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_AI_ACTION_POSITION_RESOLVER := preload("res://scripts/utils/ai/u_ai_action_position_resolver.gd")

@export var scan_component_type: StringName = &""
@export var scan_filter: StringName = &""
@export var scan_required_resource_type: StringName = &""
@export var scan_required_harvest_tag: StringName = &""
@export var use_build_site_missing_material: bool = false
@export var arrival_threshold: float = 1.5

func start(context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.COMPLETED] = false
	var entity_position: Variant = _resolve_current_position(context)
	if not (entity_position is Vector3):
		push_error("RS_AIActionMoveToNearest.start: cannot resolve entity position.")
		_mark_completed(context, task_state, "missing_position")
		return
	var scan_result: Dictionary = _find_nearest(context, task_state, entity_position as Vector3)
	var target_entity: Node = scan_result.get("entity", null)
	if target_entity == null or not is_instance_valid(target_entity):
		print("[ACTION] %s MoveToNearest skipped (no target)" % _resolve_entity_label(context))
		_mark_completed(context, task_state, "no_target_found")
		return
	var target_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(target_entity)
	if not (target_position_variant is Vector3):
		_mark_completed(context, task_state, "missing_target_position")
		return
	var target_position: Vector3 = target_position_variant as Vector3
	var resolved_threshold: float = maxf(arrival_threshold, 0.0)
	_set_move_target_component_target(context, target_position, resolved_threshold)
	var detection: Object = _resolve_detection_component(context)
	if detection != null:
		detection.set("last_scan_entity_id", U_ECS_UTILS.get_entity_id(target_entity))
	task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_threshold
	var target_id: StringName = U_ECS_UTILS.get_entity_id(target_entity)
	var distance: float = float(scan_result.get("distance", INF))
	print("[ACTION] %s MoveToNearest → target=%s dist=%.2f pos=(%.1f, %.1f, %.1f)" % [
		_resolve_entity_label(context),
		target_id,
		distance,
		target_position.x,
		target_position.y,
		target_position.z,
	])

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	if bool(task_state.get(U_AITaskStateKeys.COMPLETED, false)):
		return true
	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	if not (target_variant is Vector3):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return true
	var current_variant: Variant = _resolve_current_position(context)
	if not (current_variant is Vector3):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return true
	var target_position: Vector3 = target_variant as Vector3
	var current_position: Vector3 = current_variant as Vector3
	var offset_xz: Vector2 = Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	var resolved_threshold: float = maxf(
		float(task_state.get(U_AITaskStateKeys.ARRIVAL_THRESHOLD, arrival_threshold)), 0.0
	)
	if offset_xz.length() <= resolved_threshold:
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.COMPLETED] = true
		print("[ACTION] %s MoveToNearest arrived" % _resolve_entity_label(context))
		return true
	return false

func _find_nearest(context: Dictionary, task_state: Dictionary, origin: Vector3) -> Dictionary:
	var manager_variant: Variant = context.get("ecs_manager", null)
	if manager_variant == null or not manager_variant.has_method("get_components"):
		return {}
	var components: Array = manager_variant.call("get_components", scan_component_type)
	var best_entity: Node = null
	var best_distance: float = INF
	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant as Object):
			continue
		var component: Object = component_variant as Object
		if scan_filter != StringName("") and component.has_method(scan_filter):
			var filter_result: Variant = component.call(scan_filter)
			if not (filter_result is bool and filter_result):
				continue
		if not _matches_component_requirements(component, context, task_state):
			continue
		var entity_root: Node = U_ECS_UTILS.find_entity_root(component as Node)
		if entity_root == null or not is_instance_valid(entity_root):
			continue
		if not (entity_root is Node3D):
			continue
		var target_pos_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(entity_root)
		if not (target_pos_variant is Vector3):
			continue
		var target_pos: Vector3 = target_pos_variant as Vector3
		var dist_xz: Vector2 = Vector2(target_pos.x - origin.x, target_pos.z - origin.z)
		var distance: float = dist_xz.length()
		if distance < best_distance:
			best_distance = distance
			best_entity = entity_root
	return {"entity": best_entity, "distance": best_distance}

func _matches_component_requirements(component: Object, context: Dictionary, task_state: Dictionary) -> bool:
	var resolved_required_resource_type: StringName = _resolve_required_resource_type(context, task_state)
	if resolved_required_resource_type == StringName("") and scan_required_harvest_tag == StringName(""):
		return true
	var settings_variant: Variant = component.get("settings")
	if not (settings_variant is Resource):
		return false
	if resolved_required_resource_type != StringName(""):
		var resource_type_variant: Variant = settings_variant.get("resource_type")
		var resource_type: StringName = resource_type_variant as StringName if resource_type_variant is StringName else StringName("")
		if resource_type != resolved_required_resource_type:
			return false
	if scan_required_harvest_tag != StringName(""):
		var harvest_tag_variant: Variant = settings_variant.get("harvest_tag")
		var harvest_tag: StringName = harvest_tag_variant as StringName if harvest_tag_variant is StringName else StringName("")
		if harvest_tag != scan_required_harvest_tag:
			return false
	return true

func _resolve_required_resource_type(context: Dictionary, task_state: Dictionary) -> StringName:
	if use_build_site_missing_material:
		var build_site: Object = _resolve_build_site_component(context)
		if build_site != null and build_site.has_method("get_next_missing_material_type"):
			var missing_type_variant: Variant = build_site.call("get_next_missing_material_type")
			if missing_type_variant is StringName:
				var missing_type: StringName = missing_type_variant as StringName
				if missing_type != StringName(""):
					return missing_type
	var reserved_type_variant: Variant = task_state.get(U_AITaskStateKeys.INVENTORY_RESERVED_TYPE, StringName(""))
	if reserved_type_variant is StringName:
		var reserved_type: StringName = reserved_type_variant as StringName
		if reserved_type != StringName(""):
			return reserved_type
	return scan_required_resource_type

func _mark_completed(context: Dictionary, task_state: Dictionary, _reason: String) -> void:
	_clear_move_target_component(context)
	task_state[U_AITaskStateKeys.COMPLETED] = true

func _resolve_current_position(context: Dictionary) -> Variant:
	return U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)

func _resolve_detection_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(DETECTION_COMPONENT_TYPE, null) as Object

func _resolve_build_site_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(BUILD_SITE_COMPONENT_TYPE, null)

func _resolve_move_target_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var mt_variant: Variant = components.get(MOVE_TARGET_COMPONENT_TYPE, null)
	if not (mt_variant is Object):
		return null
	return mt_variant as Object

func _set_move_target_component_target(
	context: Dictionary,
	target_position_value: Vector3,
	arrival_threshold_value: float
) -> void:
	var move_target: Object = _resolve_move_target_component(context)
	if move_target == null:
		return
	move_target.set("target_position", target_position_value)
	move_target.set("arrival_threshold", maxf(arrival_threshold_value, 0.0))
	move_target.set("is_active", true)

func _clear_move_target_component(context: Dictionary) -> void:
	var move_target: Object = _resolve_move_target_component(context)
	if move_target == null:
		return
	move_target.set("is_active", false)

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
