extends Object
class_name U_EntityLookup

## Tag- and metadata-driven entity identification utility.
##
## Replaces fragile node-name-prefix conventions with explicit tag/metadata
## lookups. All methods are static so no instance is required.
##
## Usage:
##   var player := U_EntityLookup.find_entity_by_tag(ecs_manager, &"player")
##   var id := U_EntityLookup.resolve_entity_id(entity)

## Returns the first entity registered under `tag`, or null if none found.
static func find_entity_by_tag(ecs_manager: Node, tag: StringName) -> Node:
	if ecs_manager == null:
		return null
	var raw: Variant = ecs_manager.get_entities_by_tag(tag)
	if not (raw is Array):
		return null
	var results: Array = raw as Array
	if results.is_empty():
		return null
	return results[0] as Node

## Returns all entities registered under `tag` as an Array.
static func find_entities_by_tag(ecs_manager: Node, tag: StringName) -> Array:
	if ecs_manager == null:
		return []
	var raw: Variant = ecs_manager.get_entities_by_tag(tag)
	if not (raw is Array):
		return []
	return (raw as Array).duplicate()

## Resolves the entity ID for a node.
##
## Priority:
##   1. "entity_id" node metadata (set via `set_meta`)
##   2. BaseECSEntity.get_entity_id() (uses export field or name-stripping fallback)
##   3. Raw node name lowercased
static func resolve_entity_id(entity: Node) -> StringName:
	if entity == null:
		return StringName("")

	if entity.has_meta("entity_id"):
		return StringName(str(entity.get_meta("entity_id")))

	if entity.has_method("get_entity_id"):
		return entity.get_entity_id()

	return StringName(entity.name.to_lower())
