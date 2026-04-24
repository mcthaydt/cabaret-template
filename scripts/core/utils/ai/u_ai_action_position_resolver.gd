extends RefCounted
class_name U_AIActionPositionResolver

const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const U_ECS_UTILS := preload("res://scripts/core/utils/ecs/u_ecs_utils.gd")

static func resolve_actor_position(context: Dictionary) -> Variant:
	var explicit_position: Variant = context.get("entity_position", null)
	if explicit_position is Vector3:
		return explicit_position

	var movement_position: Variant = resolve_movement_component_position(_resolve_movement_component(context))
	if movement_position is Vector3:
		return movement_position

	var entity_variant: Variant = context.get("entity", null)
	if entity_variant is Node3D:
		return (entity_variant as Node3D).global_position

	return null

static func resolve_entity_position(entity: Node) -> Variant:
	if entity == null or not is_instance_valid(entity):
		return null

	var movement_position: Variant = resolve_movement_component_position(_resolve_entity_movement_component(entity))
	if movement_position is Vector3:
		return movement_position

	if entity is Node3D:
		return (entity as Node3D).global_position

	return null

static func resolve_movement_component_position(movement_component: Object) -> Variant:
	if movement_component == null or not is_instance_valid(movement_component):
		return null
	if not movement_component.has_method("get_character_body"):
		return null
	var body_variant: Variant = movement_component.call("get_character_body")
	if body_variant is Node3D and is_instance_valid(body_variant as Node3D):
		return (body_variant as Node3D).global_position
	return null

static func _resolve_movement_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if components_variant is Dictionary:
		var components: Dictionary = components_variant as Dictionary
		var movement_variant: Variant = components.get(C_MOVEMENT_COMPONENT.COMPONENT_TYPE, null)
		if movement_variant is Object:
			return movement_variant as Object
	return null

static func _resolve_entity_movement_component(entity: Node) -> Object:
	var manager: Node = U_ECS_UTILS.get_manager(entity)
	if manager != null and manager.has_method("get_components_for_entity_readonly"):
		var components_variant: Variant = manager.call("get_components_for_entity_readonly", entity)
		if components_variant is Dictionary:
			var components: Dictionary = components_variant as Dictionary
			var movement_variant: Variant = components.get(C_MOVEMENT_COMPONENT.COMPONENT_TYPE, null)
			if movement_variant is Object:
				return movement_variant as Object

	var child_component: Node = entity.get_node_or_null("Components/C_MovementComponent")
	if child_component is Object:
		return child_component as Object
	return null
