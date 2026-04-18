@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_decorator.gd"
class_name RS_BTOnce

const STATE_KEY_HAS_COMPLETED := &"has_completed"

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if child == null:
		push_error("RS_BTOnce.tick: child is null")
		return Status.FAILURE

	if _has_completed(state_bag):
		return Status.FAILURE

	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.SUCCESS:
		_set_completed(state_bag, true)
		return Status.SUCCESS
	if child_status == Status.RUNNING:
		return Status.RUNNING
	if child_status == Status.FAILURE:
		return Status.FAILURE

	push_error("RS_BTOnce.tick: child returned invalid status %s" % str(child_status))
	return Status.FAILURE

func _set_completed(state_bag: Dictionary, is_completed: bool) -> void:
	state_bag[node_id] = {
		STATE_KEY_HAS_COMPLETED: is_completed,
	}

func _has_completed(state_bag: Dictionary) -> bool:
	var local_state: Dictionary = _get_local_state(state_bag)
	return bool(local_state.get(STATE_KEY_HAS_COMPLETED, false))

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return state_variant as Dictionary
	return {}
