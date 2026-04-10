@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/ai/rs_ai_task.gd"
class_name RS_AICompoundTask

var _subtasks: Array[RS_AITask] = []
var _method_conditions: Array[I_Condition] = []

@export var subtasks: Array[RS_AITask] = []:
	get:
		return _subtasks
	set(value):
		_subtasks = _coerce_subtasks(value)
@export var method_conditions: Array[I_Condition] = []:
	get:
		return _method_conditions
	set(value):
		_method_conditions = _coerce_method_conditions(value)

func _coerce_subtasks(value: Variant) -> Array[RS_AITask]:
	var coerced: Array[RS_AITask] = []
	if not (value is Array):
		return coerced
	for task_variant in value as Array:
		if task_variant is RS_AITask:
			coerced.append(task_variant as RS_AITask)
	return coerced

func _coerce_method_conditions(value: Variant) -> Array[I_Condition]:
	var coerced: Array[I_Condition] = []
	if not (value is Array):
		return coerced
	for condition_variant in value as Array:
		if condition_variant is I_Condition:
			coerced.append(condition_variant as I_Condition)
	return coerced
