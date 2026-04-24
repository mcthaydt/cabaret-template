@icon("res://assets/editor_icons/icn_entities.svg")
extends I_ECSEntity
class_name BaseECSEntity

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const I_ECS_MANAGER := preload("res://scripts/core/interfaces/i_ecs_manager.gd")

@export var entity_id: StringName = StringName("")
@export var tags: Array[StringName] = []

var _cached_entity_id: StringName = StringName("")

func _ready() -> void:
	var manager := U_ECS_UTILS.get_manager(self) as I_ECSManager
	if manager != null:
		manager.cache_entity_for_node(self, self)

## Returns the unique identifier for this entity.
##
## Lookup order (C10: metadata-primary, name-stripping fallback):
##   1. entity_id @export field (explicit designer assignment)
##   2. "entity_id" node metadata (set via set_meta at runtime or in scene)
##   3. Cached result from a prior _generate_id_from_name() call
##   4. _generate_id_from_name() — strips "E_" prefix, lowercases
func get_entity_id() -> StringName:
	if entity_id != StringName(""):
		return entity_id

	if has_meta("entity_id"):
		var meta_id := StringName(str(get_meta("entity_id")))
		if meta_id != StringName(""):
			return meta_id

	if _cached_entity_id == StringName(""):
		_cached_entity_id = _generate_id_from_name()

	return _cached_entity_id

## Generates an entity ID by stripping the E_ prefix and converting to lowercase.
func _generate_id_from_name() -> StringName:
	var node_name := String(name)

	# Strip E_ prefix if present
	if node_name.begins_with("E_"):
		node_name = node_name.substr(2)

	# Convert to lowercase
	node_name = node_name.to_lower()

	return StringName(node_name)

## Allows the manager to update the entity ID (used when handling duplicates).
func set_entity_id(id: StringName) -> void:
	entity_id = id
	_cached_entity_id = id

## Returns a duplicate of the tags array (defensive copy).
func get_tags() -> Array[StringName]:
	return tags.duplicate()

## Checks if this entity has the specified tag.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

## Adds a tag to this entity if not already present.
## Notifies the manager to update its tag index.
func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)
		_notify_tags_changed()

## Removes a tag from this entity if present.
## Notifies the manager to update its tag index.
func remove_tag(tag: StringName) -> void:
	var idx := tags.find(tag)
	if idx >= 0:
		tags.remove_at(idx)
		_notify_tags_changed()

## Notifies the ECS manager that this entity's tags have changed.
func _notify_tags_changed() -> void:
	var manager := U_ECS_UTILS.get_manager(self) as I_ECSManager
	if manager != null:
		manager.update_entity_tags(self)
