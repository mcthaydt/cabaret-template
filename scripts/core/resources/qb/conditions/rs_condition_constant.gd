@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_condition.gd"
class_name RS_ConditionConstant

@export_range(0.0, 1.0) var score: float = 1.0

func _evaluate_raw(_context: Dictionary) -> float:
	return score
