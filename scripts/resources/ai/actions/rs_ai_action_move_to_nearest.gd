@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionMoveToNearest

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

@export var scan_component_type: StringName = &""
@export var scan_filter: StringName = &""
@export var arrival_threshold: float = 1.5

func start(context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.COMPLETED] = false
	var entity_position: Variant = _resolve_current_position(context)
	if not (entity_position is Vector3):
		push_error("RS_AIActionMoveToNearest.start: cannot resolve entity position.")
		_mark_completed(context, task_state, "missing_position")
		return
	var scan_result: Dictionary = _find_nearest(context, entity_position as Vector3)
	var target_entity: Node = scan_result.get("entity", null)
	if target_entity == null or not is_instance_valid(target_entity):
		_mark_completed(context, task_state, "no_target_found")
		return
	var target_position: Vector3 = (target_entity as Node3D).global_position
	var resolved_threshold: float = maxf(arrival_threshold, 0.0)
	_set_move_target_component_target(context, target_position, resolved_threshold)
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection != null:
		detection.last_scan_entity_id = U_ECS_UTILS.get_entity_id(target_entity)
	task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_threshold

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
		return true
	return false

func _find_nearest(context: Dictionary, origin: Vector3) -> Dictionary:
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
		var entity_root: Node = U_ECS_UTILS.find_entity_root(component as Node)
		if entity_root == null or not is_instance_valid(entity_root):
			continue
		if not (entity_root is Node3D):
			continue
		var target_pos: Vector3 = (entity_root as Node3D).global_position
		var dist_xz: Vector2 = Vector2(target_pos.x - origin.x, target_pos.z - origin.z)
		var distance: float = dist_xz.length()
		if distance < best_distance:
			best_distance = distance
			best_entity = entity_root
	return {"entity": best_entity, "distance": best_distance}

func _mark_completed(context: Dictionary, task_state: Dictionary, _reason: String) -> void:
	_clear_move_target_component(context)
	task_state[U_AITaskStateKeys.COMPLETED] = true

func _resolve_current_position(context: Dictionary) -> Variant:
	var entity_position_variant: Variant = context.get("entity_position", null)
	if entity_position_variant is Vector3:
		return entity_position_variant
	var entity: Node3D = context.get("entity", null) as Node3D
	if entity != null and is_instance_valid(entity):
		return entity.global_position
	return null

func _resolve_detection_component(context: Dictionary) -> C_DetectionComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_DETECTION_COMPONENT.COMPONENT_TYPE, null) as C_DetectionComponent

func _resolve_move_target_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var mt_variant: Variant = components.get(C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE, null)
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