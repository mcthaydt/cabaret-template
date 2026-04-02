@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIBrainSettings

@export var goals: Array[Resource] = []
@export var default_goal_id: StringName
@export var evaluation_interval: float = 0.5
