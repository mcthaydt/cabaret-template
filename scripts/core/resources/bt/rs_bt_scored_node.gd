@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_decorator.gd"
class_name RS_BTScoredNode

@export var scorer: Resource = null

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if _child == null:
		return Status.FAILURE
	return _child.tick(context, state_bag)
