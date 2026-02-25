@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SceneDirectorInitialState

## Initial state for scene_director slice.

@export var active_directive_id: StringName = StringName("")
@export var current_beat_index: int = -1
@export var state: String = "idle"

func to_dictionary() -> Dictionary:
	return {
		"active_directive_id": active_directive_id,
		"current_beat_index": current_beat_index,
		"state": state,
	}

