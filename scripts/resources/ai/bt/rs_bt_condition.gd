@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_node.gd"
class_name RS_BTCondition

@export var condition: I_Condition = null

func tick(context: Dictionary, _state_bag: Dictionary) -> Status:
	if condition == null:
		push_error("RS_BTCondition.tick: condition is null")
		return Status.FAILURE

	var score_variant: Variant = condition.evaluate(context)
	if not (score_variant is float or score_variant is int):
		push_error("RS_BTCondition.tick: condition returned non-numeric score %s" % str(score_variant))
		return Status.FAILURE

	var score: float = float(score_variant)
	return Status.SUCCESS if score > 0.0 else Status.FAILURE
