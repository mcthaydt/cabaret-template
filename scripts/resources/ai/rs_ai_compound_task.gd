@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/ai/rs_ai_task.gd"
class_name RS_AICompoundTask

@export var subtasks: Array[Resource] = []
@export var method_conditions: Array[Resource] = []
