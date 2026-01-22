extends Node3D
class_name I_ECSEntity

## Interface for ECS entities
##
## Entities are the root nodes that hold collections of components.
## They have unique IDs and tags for querying and categorization.
##
## Phase: Duck Typing Cleanup Phase 2 (2026-01-22)
## Created to enable type-safe entity operations and remove has_method() checks
##
## Implementations:
## - BaseECSEntity (production base class)
## - MockECSEntity (testing)

## Returns the unique identifier for this entity.
##
## @return StringName: The entity's unique ID
func get_entity_id() -> StringName:
	push_error("I_ECSEntity.get_entity_id not implemented")
	return StringName("")

## Sets the entity ID (used by manager for duplicate resolution).
##
## @param id: The new entity ID to assign
func set_entity_id(_id: StringName) -> void:
	push_error("I_ECSEntity.set_entity_id not implemented")

## Returns a copy of the entity's tags array.
##
## @return Array[StringName]: Copy of tags for safe iteration
func get_tags() -> Array[StringName]:
	push_error("I_ECSEntity.get_tags not implemented")
	return []

## Checks if the entity has a specific tag.
##
## @param tag: Tag to check for
## @return bool: True if the entity has this tag
func has_tag(_tag: StringName) -> bool:
	push_error("I_ECSEntity.has_tag not implemented")
	return false

## Adds a tag to the entity if not already present.
##
## @param tag: Tag to add
func add_tag(_tag: StringName) -> void:
	push_error("I_ECSEntity.add_tag not implemented")

## Removes a tag from the entity if present.
##
## @param tag: Tag to remove
func remove_tag(_tag: StringName) -> void:
	push_error("I_ECSEntity.remove_tag not implemented")
