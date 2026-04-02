@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIGoal

@export var goal_id: StringName
@export var conditions: Array[Resource] = []
@export var root_task: Resource = null
@export var priority: int = 0
