@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_ObjectiveDefinition

## Scene Director objective definition resource.
##
## Notes:
## - CHECKPOINT exists for authoring compatibility and future behavior.
## - Condition/effect arrays stay Array[Resource] for headless parser stability.

enum ObjectiveType {
	STANDARD = 0,
	VICTORY = 1,
	CHECKPOINT = 2,
}

@export var objective_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var objective_type: ObjectiveType = ObjectiveType.STANDARD
@export var conditions: Array[Resource] = []
@export var completion_effects: Array[Resource] = []
@export var completion_event_payload: Dictionary = {}
@export var dependencies: Array[StringName] = []
@export var auto_activate: bool = false
