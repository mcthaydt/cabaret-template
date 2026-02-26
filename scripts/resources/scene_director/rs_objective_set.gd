@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_ObjectiveSet

## Scene Director objective set resource.
##
## Notes:
## - objectives remains Array[Resource] for headless parser stability.
## - entries should be RS_ObjectiveDefinition resources.

@export var set_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var objectives: Array[Resource] = []
