@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_BeatDefinition

## Scene Director beat definition resource.
##
## Notes:
## - preconditions/effects remain Array[Resource] for headless parser stability.

enum WaitMode {
	INSTANT = 0,
	TIMED = 1,
	SIGNAL = 2,
}

@export var beat_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var preconditions: Array[Resource] = []
@export var effects: Array[Resource] = []
@export var wait_mode: WaitMode = WaitMode.INSTANT
@export_range(0.0, 600.0, 0.01, "or_greater") var duration: float = 0.0
@export var wait_event: StringName = StringName("")

