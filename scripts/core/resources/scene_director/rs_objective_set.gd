@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_ObjectiveSet

## Scene Director objective set resource.

var _objectives: Array[RS_ObjectiveDefinition] = []

@export var set_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var objectives: Array[RS_ObjectiveDefinition] = []:
	get:
		return _objectives
	set(value):
		_objectives = _sanitize_objectives(value)


func _sanitize_objectives(value: Variant) -> Array[RS_ObjectiveDefinition]:
	var sanitized: Array[RS_ObjectiveDefinition] = []
	if not (value is Array):
		return sanitized
	for objective_variant in value as Array:
		if objective_variant is RS_ObjectiveDefinition:
			sanitized.append(objective_variant as RS_ObjectiveDefinition)
	return sanitized
