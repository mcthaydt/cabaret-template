@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer.gd"
class_name RS_AIScorerCondition

@export var condition: I_Condition = null
@export var if_true: float = 1.0
@export var if_false: float = 0.0

func score(context: Dictionary) -> float:
	if condition == null:
		push_error("RS_AIScorerCondition.score: condition is null")
		return if_false

	var condition_score: Variant = condition.evaluate(context)
	if condition_score is float or condition_score is int:
		return if_true if float(condition_score) > 0.0 else if_false

	push_error("RS_AIScorerCondition.score: condition returned non-numeric score %s" % str(condition_score))
	return if_false
