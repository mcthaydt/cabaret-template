@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionReserve

const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/demo/ecs/components/c_resource_node_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")

@export var reserve_duration_seconds: float = 10.0

func start(context: Dictionary, task_state: Dictionary) -> void:
	var resource_node: Object = _resolve_resource_node(context, task_state)
	if resource_node == null:
		task_state[U_AITaskStateKeys.COMPLETED] = true
		print("[ACTION] %s Reserve skipped (no resource node)" % _resolve_entity_label(context))
		return
	if resource_node.has_method("is_available"):
		var available_variant: Variant = resource_node.call("is_available")
		if available_variant is bool and not bool(available_variant):
			task_state[U_AITaskStateKeys.COMPLETED] = true
			print("[ACTION] %s Reserve skipped (resource unavailable)" % _resolve_entity_label(context))
			return
	var entity_id_variant: Variant = context.get("entity_id", StringName(""))
	var entity_id: StringName = entity_id_variant as StringName if entity_id_variant is StringName else StringName("")
	resource_node.set("reserved_by_entity_id", entity_id)
	var reserved_type: StringName = StringName("")
	var settings_variant: Variant = resource_node.get("settings")
	if settings_variant is Resource:
		reserved_type = StringName(settings_variant.get("resource_type"))
	task_state[U_AITaskStateKeys.INVENTORY_RESERVED_TYPE] = reserved_type
	task_state[U_AITaskStateKeys.COMPLETED] = true
	print("[ACTION] %s Reserve → entity_id=%s type=%s duration=%.2fs" % [
		_resolve_entity_label(context),
		entity_id,
		reserved_type,
		maxf(reserve_duration_seconds, 0.0),
	])

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.COMPLETED, false))

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

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
