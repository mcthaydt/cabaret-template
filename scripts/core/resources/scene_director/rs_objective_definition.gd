@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_ObjectiveDefinition

## Scene Director objective definition resource.
##
## Notes:
## - CHECKPOINT exists for authoring compatibility and future behavior.

enum ObjectiveType {
	STANDARD = 0,
	VICTORY = 1,
	CHECKPOINT = 2,
}

var _conditions: Array[I_Condition] = []
var _completion_effects: Array[I_Effect] = []

@export var objective_id: StringName = StringName("")
@export_multiline var description: String = ""
@export var objective_type: ObjectiveType = ObjectiveType.STANDARD
@export var conditions: Array[I_Condition] = []:
	get:
		return _conditions
	set(value):
		_conditions = _coerce_conditions(value)
@export var completion_effects: Array[I_Effect] = []:
	get:
		return _completion_effects
	set(value):
		_completion_effects = _coerce_effects(value)
@export var completion_event_payload: Dictionary = {}
@export var dependencies: Array[StringName] = []
@export var auto_activate: bool = false


func _coerce_conditions(value: Variant) -> Array[I_Condition]:
	var coerced: Array[I_Condition] = []
	if not (value is Array):
		return coerced
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			coerced.append(condition_variant as I_Condition)
	return coerced


func _coerce_effects(value: Variant) -> Array[I_Effect]:
	var coerced: Array[I_Effect] = []
	if not (value is Array):
		return coerced
	for effect_variant in value as Array:
		if effect_variant is I_Effect:
			coerced.append(effect_variant as I_Effect)
	return coerced
