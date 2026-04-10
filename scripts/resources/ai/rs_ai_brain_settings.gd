@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIBrainSettings

var _goals: Array[RS_AIGoal] = []

@export var goals: Array[RS_AIGoal] = []:
	get:
		return _goals
	set(value):
		_goals = _coerce_goals(value)
@export var default_goal_id: StringName
@export var evaluation_interval: float = 0.5
@export var respawn_spawn_point_id: StringName = StringName("")
@export var respawn_unsupported_delay_sec: float = 0.6
@export var respawn_recovery_cooldown_sec: float = 1.0

func _coerce_goals(value: Variant) -> Array[RS_AIGoal]:
	var coerced: Array[RS_AIGoal] = []
	if not (value is Array):
		return coerced
	for goal_variant in value as Array:
		if goal_variant is RS_AIGoal:
			coerced.append(goal_variant as RS_AIGoal)
	return coerced
