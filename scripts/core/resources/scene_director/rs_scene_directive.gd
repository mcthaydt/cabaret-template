@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SceneDirective

## Scene Director directive definition resource.

var _selection_conditions: Array[I_Condition] = []
var _beats: Array[RS_BeatDefinition] = []

@export var directive_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var target_scene_id: StringName = StringName("")
@export var selection_conditions: Array[I_Condition] = []:
	get:
		return _selection_conditions
	set(value):
		_selection_conditions = _sanitize_conditions(value)
@export_range(-1000, 1000, 1) var priority: int = 0
@export var beats: Array[RS_BeatDefinition] = []:
	get:
		return _beats
	set(value):
		_beats = _sanitize_beats(value)


func _sanitize_conditions(value: Variant) -> Array[I_Condition]:
	var sanitized: Array[I_Condition] = []
	if not (value is Array):
		return sanitized
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			sanitized.append(condition_variant as I_Condition)
	return sanitized


func _sanitize_beats(value: Variant) -> Array[RS_BeatDefinition]:
	var sanitized: Array[RS_BeatDefinition] = []
	if not (value is Array):
		return sanitized
	for beat_variant in value as Array:
		if beat_variant is RS_BeatDefinition:
			sanitized.append(beat_variant as RS_BeatDefinition)
	return sanitized
