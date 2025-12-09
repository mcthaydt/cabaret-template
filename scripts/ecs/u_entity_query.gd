extends RefCounted

class_name U_EntityQuery

const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

var entity: Node = null

var _components: Dictionary = {}

var components: Dictionary:
	set(value):
		if value == null:
			_components = {}
			return
		if value is Dictionary:
			_components = (value as Dictionary).duplicate(true)
			return
		push_warning("U_EntityQuery.components expects a Dictionary of components.")
		_components = {}
	get:
		return _components.duplicate(true)

func get_component(component_type: StringName) -> BaseECSComponent:
	return _components.get(component_type) as BaseECSComponent

func has_component(component_type: StringName) -> bool:
	if not _components.has(component_type):
		return false
	return _components.get(component_type) != null

func get_all_components() -> Dictionary:
	return _components.duplicate(true)

## Returns the entity ID for this query's entity.
func get_entity_id() -> StringName:
	return U_ECS_UTILS.get_entity_id(entity)

## Returns the tags for this query's entity.
func get_tags() -> Array[StringName]:
	return U_ECS_UTILS.get_entity_tags(entity)

## Checks if this query's entity has the specified tag.
func has_tag(tag: StringName) -> bool:
	return get_tags().has(tag)
