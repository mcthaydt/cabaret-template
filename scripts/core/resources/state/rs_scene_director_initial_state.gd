@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SceneDirectorInitialState

## Initial state for scene_director slice.

@export var active_directive_id: StringName = StringName("")
@export var current_beat_index: int = -1
@export var current_beat_id: StringName = StringName("")
@export var active_beat_ids: Array[StringName] = []
@export var parallel_lane_ids: Array[StringName] = []
@export var state: String = "idle"

func to_dictionary() -> Dictionary:
	return {
		"active_directive_id": active_directive_id,
		"current_beat_index": current_beat_index,
		"current_beat_id": current_beat_id,
		"active_beat_ids": active_beat_ids.duplicate(),
		"parallel_lane_ids": parallel_lane_ids.duplicate(),
		"state": state,
	}
