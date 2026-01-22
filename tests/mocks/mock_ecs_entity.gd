extends I_ECSEntity
class_name MockECSEntity

## Minimal mock for I_ECSEntity
##
## Provides a simple implementation of the entity interface for testing.
## Does not include the full BaseECSEntity logic (ID generation, manager notifications).
##
## Phase: Duck Typing Cleanup Phase 2 (2026-01-22)
## Created to enable isolated testing of entity-dependent code

var _entity_id: StringName = StringName("")
var _tags: Array[StringName] = []

func get_entity_id() -> StringName:
	return _entity_id

func set_entity_id(id: StringName) -> void:
	_entity_id = id

func get_tags() -> Array[StringName]:
	return _tags.duplicate()

func has_tag(tag: StringName) -> bool:
	return _tags.has(tag)

func add_tag(tag: StringName) -> void:
	if not _tags.has(tag):
		_tags.append(tag)

func remove_tag(tag: StringName) -> void:
	var idx := _tags.find(tag)
	if idx >= 0:
		_tags.remove_at(idx)
