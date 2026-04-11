@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/ai/tasks/rs_ai_task.gd"
class_name RS_AIPrimitiveTask

var _action: I_AIAction = null

@export var action: I_AIAction = null:
	get:
		return _action
	set(value):
		_action = value if value is I_AIAction else null
