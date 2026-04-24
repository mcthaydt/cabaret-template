@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_decorator.gd"
class_name RS_BTRisingEdge

const STATE_KEY_WAS_TRUE := &"was_true"
const STATE_KEY_IS_RUNNING := &"is_running"

@export var gate_condition: Resource = null

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if child == null:
		push_error("RS_BTRisingEdge.tick: child is null")
		return Status.FAILURE
	if gate_condition == null:
		push_error("RS_BTRisingEdge.tick: gate_condition is null")
		return Status.FAILURE

	var gate_is_true: bool = _is_gate_true(context)
	var local_state: Dictionary = _get_local_state(state_bag)
	var was_true: bool = bool(local_state.get(STATE_KEY_WAS_TRUE, false))
	var is_running: bool = bool(local_state.get(STATE_KEY_IS_RUNNING, false))

	if is_running:
		return _tick_running_child(context, state_bag, gate_is_true)

	if not gate_is_true or was_true:
		_set_local_state(state_bag, gate_is_true, false)
		return Status.FAILURE

	return _tick_fresh_entry(context, state_bag, gate_is_true)

func _tick_fresh_entry(context: Dictionary, state_bag: Dictionary, gate_is_true: bool) -> Status:
	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.RUNNING:
		_set_local_state(state_bag, gate_is_true, true)
		return Status.RUNNING
	if child_status == Status.SUCCESS:
		_set_local_state(state_bag, gate_is_true, false)
		return Status.SUCCESS
	if child_status == Status.FAILURE:
		_set_local_state(state_bag, gate_is_true, false)
		return Status.FAILURE

	push_error("RS_BTRisingEdge.tick: child returned invalid status %s" % str(child_status))
	_set_local_state(state_bag, gate_is_true, false)
	return Status.FAILURE

func _tick_running_child(context: Dictionary, state_bag: Dictionary, gate_is_true: bool) -> Status:
	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.RUNNING:
		_set_local_state(state_bag, gate_is_true, true)
		return Status.RUNNING
	if child_status == Status.SUCCESS:
		_set_local_state(state_bag, gate_is_true, false)
		return Status.SUCCESS
	if child_status == Status.FAILURE:
		_set_local_state(state_bag, gate_is_true, false)
		return Status.FAILURE

	push_error("RS_BTRisingEdge.tick: child returned invalid status %s" % str(child_status))
	_set_local_state(state_bag, gate_is_true, false)
	return Status.FAILURE

func _is_gate_true(context: Dictionary) -> bool:
	if not gate_condition.has_method("evaluate"):
		push_error("RS_BTRisingEdge.tick: gate_condition must implement evaluate(context)")
		return false

	var score_variant: Variant = gate_condition.call("evaluate", context)
	if not (score_variant is float):
		push_error("RS_BTRisingEdge.tick: gate_condition returned non-numeric score %s" % str(score_variant))
		return false

	return float(score_variant) > 0.0

func _set_local_state(state_bag: Dictionary, was_true: bool, is_running: bool) -> void:
	state_bag[node_id] = {
		STATE_KEY_WAS_TRUE: was_true,
		STATE_KEY_IS_RUNNING: is_running,
	}

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return state_variant as Dictionary
	return {}
