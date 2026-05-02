@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_composite.gd"
class_name RS_BTSequence

const STATE_KEY_CURRENT_CHILD_INDEX := &"current_child_index"

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if children.is_empty():
		_clear_local_state(state_bag)
		return Status.SUCCESS

	var start_index: int = _get_current_child_index(state_bag)
	if start_index < 0 or start_index >= children.size():
		start_index = 0

	for index in range(start_index, children.size()):
		var child: RS_BTNode = children[index]
		if child == null:
			push_error("RS_BTSequence.tick: child at index %d is null" % index)
			_clear_local_state(state_bag)
			return Status.FAILURE

		var child_status: int = child.tick(context, state_bag)
		match child_status:
			Status.RUNNING:
				_set_current_child_index(state_bag, index)
				return Status.RUNNING
			Status.FAILURE:
				_clear_local_state(state_bag)
				return Status.FAILURE
			Status.SUCCESS:
				continue
			_:
				push_error("RS_BTSequence.tick: child returned invalid status %s" % str(child_status))
				_clear_local_state(state_bag)
				return Status.FAILURE

	_clear_local_state(state_bag)
	return Status.SUCCESS

func _get_current_child_index(state_bag: Dictionary) -> int:
	var local_state: Dictionary = _get_local_state(state_bag)
	var index_variant: Variant = local_state.get(STATE_KEY_CURRENT_CHILD_INDEX, 0)
	return int(index_variant)

func _set_current_child_index(state_bag: Dictionary, index: int) -> void:
	state_bag[node_id] = {
		STATE_KEY_CURRENT_CHILD_INDEX: index,
	}

func _clear_local_state(state_bag: Dictionary) -> void:
	state_bag.erase(node_id)

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return state_variant as Dictionary
	return {}
