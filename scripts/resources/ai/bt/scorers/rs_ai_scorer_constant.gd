@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/ai/bt/scorers/rs_ai_scorer.gd"
class_name RS_AIScorerConstant

@export var value: float = 0.0

func score(_context: Dictionary) -> float:
	return value
