@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIBrainSettings

@export var goals: Array[Resource] = []
@export var default_goal_id: StringName
@export var evaluation_interval: float = 0.5
@export var respawn_spawn_point_id: StringName = StringName("")
@export var respawn_unsupported_delay_sec: float = 0.6
@export var respawn_recovery_cooldown_sec: float = 1.0
