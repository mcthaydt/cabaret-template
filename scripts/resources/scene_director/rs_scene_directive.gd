@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SceneDirective

## Scene Director directive definition resource.
##
## Notes:
## - selection_conditions remain Array[Resource] for headless parser stability.
## - beats remains Array[Resource] for headless parser stability.
## - beats should contain RS_BeatDefinition resources.

@export var directive_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var target_scene_id: StringName = StringName("")
@export var selection_conditions: Array[Resource] = []
@export_range(-1000, 1000, 1) var priority: int = 0
@export var beats: Array[Resource] = []
