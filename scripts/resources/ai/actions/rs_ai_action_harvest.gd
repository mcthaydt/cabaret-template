@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionHarvest

const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/ecs/components/c_resource_node_component.gd")
const C_INVENTORY_COMPONENT := preload("res://scripts/ecs/components/c_inventory_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

@export var harvest_seconds: float = 2.0
@export var harvest_amount: int = 1

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.HARVEST_ELAPSED] = 0.0

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AITaskStateKeys.HARVEST_ELAPSED, 0.0)
	task_state[U_AITaskStateKeys.HARVEST_ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = task_state.get(U_AITaskStateKeys.HARVEST_ELAPSED, 0.0)
	if elapsed < maxf(harvest_seconds, 0.0):
		return false
	_apply_harvest(_context, task_state)
	return true

func _apply_harvest(context: Dictionary, task_state: Dictionary) -> void:
	var resource_node: Object = _resolve_resource_node(context, task_state)
	if resource_node == null:
		return
	var inventory: Object = _resolve_inventory(context)
	if inventory == null:
		return
	var taken: int = resource_node.call("harvest", harvest_amount)
	if taken <= 0:
		return
	var resource_type: StringName = StringName("")
	var settings_variant: Variant = resource_node.get("settings")
	if settings_variant is RS_ResourceNodeSettings:
		resource_type = settings_variant.resource_type
	if resource_type != StringName(""):
		inventory.call("add", resource_type, taken)

func _resolve_resource_node(context: Dictionary, task_state: Dictionary) -> Object:
	var target_id_variant: Variant = task_state.get(U_AITaskStateKeys.DETECTED_ENTITY_ID, StringName(""))
	var target_id: StringName = target_id_variant as StringName if target_id_variant is StringName else StringName("")
	if target_id == StringName(""):
		var detection: Object = _resolve_detection_component(context)
		if detection != null:
			target_id = detection.get("last_scan_entity_id") as StringName
	if target_id == StringName(""):
		return null
	var manager_variant: Variant = context.get("ecs_manager", null)
	if manager_variant == null or not manager_variant.has_method("get_entity_by_id"):
		return null
	var target_entity: Node = manager_variant.call("get_entity_by_id", target_id)
	if target_entity == null or not is_instance_valid(target_entity):
		return null
	return _find_component_on_entity(target_entity, C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE)

func _resolve_inventory(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	return components_variant.get(C_INVENTORY_COMPONENT.COMPONENT_TYPE, null)

func _resolve_detection_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_DETECTION_COMPONENT.COMPONENT_TYPE, null)

func _find_component_on_entity(entity: Node, component_type: StringName) -> Object:
	for child in entity.get_children():
		if child.has_method("get_component_type") and child.get_component_type() == component_type:
			return child
	return null