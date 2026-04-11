@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIGoal

var _conditions: Array[I_Condition] = []
var _root_task: RS_AITask = null

@export var goal_id: StringName
@export var conditions: Array[I_Condition] = []:
	get:
		return _conditions
	set(value):
		_conditions = _coerce_conditions(value)
@export var root_task: RS_AITask = null:
	get:
		return _root_task
	set(value):
		_root_task = value if value is RS_AITask else null
@export var priority: int = 0
@export var score_threshold: float = 0.0
@export var cooldown: float = 0.0
@export var one_shot: bool = false
@export var requires_rising_edge: bool = false

func _coerce_conditions(value: Variant) -> Array[I_Condition]:
	var coerced: Array[I_Condition] = []
	if not (value is Array):
		return coerced
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			coerced.append(condition_variant as I_Condition)
	return coerced
