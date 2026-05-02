@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_decorator.gd"
class_name RS_BTInverter

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if child == null:
		push_error("RS_BTInverter.tick: child is null")
		return Status.FAILURE

	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.SUCCESS:
		return Status.FAILURE
	if child_status == Status.FAILURE:
		return Status.SUCCESS
	if child_status == Status.RUNNING:
		return Status.RUNNING

	push_error("RS_BTInverter.tick: child returned invalid status %s" % str(child_status))
	return Status.FAILURE
