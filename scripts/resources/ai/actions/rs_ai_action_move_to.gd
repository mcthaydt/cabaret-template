@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/interfaces/i_ai_action.gd"
class_name RS_AIActionMoveTo

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")

@export_group("Target")
@export var target_position: Vector3 = Vector3.ZERO
@export var target_node_path: NodePath
@export var waypoint_index: int = -1
@export var arrival_threshold: float = 0.5

func start(context: Dictionary, task_state: Dictionary) -> void:
	var resolved_target: Variant = _resolve_target(context)
	if resolved_target is Vector3:
		task_state["ai_move_target"] = resolved_target
		task_state["move_target_resolved"] = true
		return
	task_state.erase("ai_move_target")
	task_state["move_target_resolved"] = false

func tick(context: Dictionary, task_state: Dictionary, _delta: float) -> void:
	var resolved_target: Variant = _resolve_target(context)
	if resolved_target is Vector3:
		task_state["ai_move_target"] = resolved_target
		task_state["move_target_resolved"] = true

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	var target_variant: Variant = task_state.get("ai_move_target", null)
	if not (target_variant is Vector3):
		return true

	var current_position_variant: Variant = _resolve_current_position(context)
	if not (current_position_variant is Vector3):
		return true

	var target: Vector3 = target_variant as Vector3
	var current_position: Vector3 = current_position_variant as Vector3
	var offset_xz := Vector2(target.x - current_position.x, target.z - current_position.z)
	return offset_xz.length() <= maxf(arrival_threshold, 0.0)

func _resolve_target(context: Dictionary) -> Variant:
	if waypoint_index >= 0:
		var waypoint_target: Variant = _resolve_waypoint_target(context)
		if waypoint_target is Vector3:
			return waypoint_target

	if target_node_path != NodePath():
		var target_node: Node3D = _resolve_target_node(context)
		if target_node != null:
			return target_node.global_position

	return target_position

func _resolve_waypoint_target(context: Dictionary) -> Variant:
	var waypoints_variant: Variant = context.get("waypoints", [])
	if not (waypoints_variant is Array):
		return null

	var waypoints: Array = waypoints_variant as Array
	if waypoint_index < 0 or waypoint_index >= waypoints.size():
		return null

	var waypoint_variant: Variant = waypoints[waypoint_index]
	if waypoint_variant is Vector3:
		return waypoint_variant
	if waypoint_variant is Node3D:
		return (waypoint_variant as Node3D).global_position
	if waypoint_variant is Dictionary:
		var waypoint_dict: Dictionary = waypoint_variant as Dictionary
		var global_position_variant: Variant = waypoint_dict.get("global_position", null)
		if global_position_variant is Vector3:
			return global_position_variant
		var position_variant: Variant = waypoint_dict.get("position", null)
		if position_variant is Vector3:
			return position_variant
	if waypoint_variant is Object:
		var waypoint_object: Object = waypoint_variant as Object
		var waypoint_global_variant: Variant = waypoint_object.get("global_position")
		if waypoint_global_variant is Vector3:
			return waypoint_global_variant
		var waypoint_position_variant: Variant = waypoint_object.get("position")
		if waypoint_position_variant is Vector3:
			return waypoint_position_variant

	return null

func _resolve_target_node(context: Dictionary) -> Node3D:
	if target_node_path == NodePath():
		return null

	var owner_variant: Variant = context.get("entity", null)
	if owner_variant is Node:
		var entity_node: Node = owner_variant as Node
		var target_from_entity: Node3D = entity_node.get_node_or_null(target_node_path) as Node3D
		if target_from_entity != null:
			return target_from_entity

	var context_owner_variant: Variant = context.get("owner_node", null)
	if context_owner_variant is Node:
		var owner_node: Node = context_owner_variant as Node
		var target_from_owner: Node3D = owner_node.get_node_or_null(target_node_path) as Node3D
		if target_from_owner != null:
			return target_from_owner

	var direct_target_variant: Variant = context.get("target_node", null)
	if direct_target_variant is Node3D:
		return direct_target_variant as Node3D

	return null

func _resolve_current_position(context: Dictionary) -> Variant:
	var position_variant: Variant = context.get("entity_position", null)
	if position_variant is Vector3:
		return position_variant

	var components_variant: Variant = context.get("components", null)
	if components_variant is Dictionary:
		var components: Dictionary = components_variant as Dictionary
		var movement_component_variant: Variant = components.get(C_MOVEMENT_COMPONENT.COMPONENT_TYPE, null)
		if movement_component_variant is Object and (movement_component_variant as Object).has_method("get_character_body"):
			var body_variant: Variant = (movement_component_variant as Object).call("get_character_body")
			if body_variant is Node3D:
				return (body_variant as Node3D).global_position

	var entity_variant: Variant = context.get("entity", null)
	if entity_variant is Node3D:
		return (entity_variant as Node3D).global_position

	return null
