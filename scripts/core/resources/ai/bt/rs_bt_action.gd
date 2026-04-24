@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_node.gd"
class_name RS_BTAction

const U_AI_TASK_STATE_KEYS := preload("res://scripts/core/utils/ai/u_ai_task_state_keys.gd")

const BT_ACTION_STATE_BAG := &"bt_action_state_bag"
const CONTEXT_KEY_DELTA := &"delta"

@export var action: I_AIAction = null

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if action == null:
		push_error("RS_BTAction.tick: action is null")
		return Status.FAILURE

	var task_state: Dictionary = _get_task_state(state_bag)
	var action_started: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false))
	if not action_started:
		action.start(context, task_state)
		task_state[U_AI_TASK_STATE_KEYS.ACTION_STARTED] = true

	action.tick(context, task_state, _resolve_delta(context))

	var complete_variant: Variant = action.is_complete(context, task_state)
	var is_complete: bool = complete_variant is bool and bool(complete_variant)
	if not is_complete:
		_set_task_state(state_bag, task_state)
		return Status.RUNNING

	_clear_local_state(state_bag)
	return Status.SUCCESS

func _resolve_delta(context: Dictionary) -> float:
	var delta_variant: Variant = context.get(CONTEXT_KEY_DELTA, 0.0)
	if delta_variant is float or delta_variant is int:
		return maxf(float(delta_variant), 0.0)
	return 0.0

func _set_task_state(state_bag: Dictionary, task_state: Dictionary) -> void:
	state_bag[node_id] = {
		BT_ACTION_STATE_BAG: task_state,
	}

func _get_task_state(state_bag: Dictionary) -> Dictionary:
	var local_state: Dictionary = _get_local_state(state_bag)
	var task_state_variant: Variant = local_state.get(BT_ACTION_STATE_BAG, {})
	if task_state_variant is Dictionary:
		return task_state_variant as Dictionary
	return {}

func _clear_local_state(state_bag: Dictionary) -> void:
	state_bag.erase(node_id)

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return state_variant as Dictionary
	return {}
