@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SpawnMetadata

## Spawn Metadata Resource
##
## Describes a single spawn point using a stable identifier, tags,
## priority, and a simple condition enum. Intended to be editor-friendly
## and consumed via U_SpawnRegistry + M_SpawnManager.
##
## Fields:
## - spawn_id: Stable identifier for the spawn point (matches Node name / id)
## - tags: Optional categorisation tags (e.g., "default", "checkpoint")
## - priority: Integer tie-breaker when multiple candidates are valid
## - condition: SpawnCondition enum (ALWAYS, CHECKPOINT_ONLY, DISABLED)

enum SpawnCondition {
	ALWAYS = 0,
	CHECKPOINT_ONLY = 1,
	DISABLED = 2
}

@export var spawn_id: StringName = StringName("")
@export var tags: Array[StringName] = []
@export_range(0, 100) var priority: int = 0
@export_enum("ALWAYS:0", "CHECKPOINT_ONLY:1", "DISABLED:2") var condition: int = SpawnCondition.ALWAYS
@export var face_camera_on_spawn: bool = false
@export var snap_to_ground_on_spawn: bool = false

## Returns true if this metadata has a non-empty spawn_id.
func is_valid() -> bool:
	return not spawn_id.is_empty()

## Returns true if this spawn is not disabled.
func is_enabled() -> bool:
	return condition != SpawnCondition.DISABLED

## Check whether this spawn has the given tag.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

## Convert to a dictionary for consumers that prefer immutable data.
func to_dictionary() -> Dictionary:
	return {
		"spawn_id": spawn_id,
		"tags": tags.duplicate(true),
		"priority": priority,
		"condition": condition,
		"face_camera_on_spawn": face_camera_on_spawn,
		"snap_to_ground_on_spawn": snap_to_ground_on_spawn
	}
