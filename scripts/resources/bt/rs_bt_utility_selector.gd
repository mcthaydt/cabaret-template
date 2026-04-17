@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_composite.gd"
class_name RS_BTUtilitySelector

const STATE_KEY_RUNNING_CHILD_INDEX := &"running_child_index"

var _scorer_callables: Array[Callable] = []
var _scorer_owners: Array[Variant] = []

@export var scorer_callables: Array[Callable] = []:
	get:
		return _scorer_callables
	set(value):
		_scorer_callables = _coerce_scorer_callables(value)
		_scorer_owners = _capture_callable_owners(_scorer_callables)

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if children.is_empty():
		_clear_local_state(state_bag)
		return Status.FAILURE

	var running_index: int = _get_running_child_index(state_bag)
	if running_index >= 0:
		return _tick_pinned_child(running_index, context, state_bag)

	var selected_index: int = _select_best_child_index(context)
	if selected_index < 0:
		_clear_local_state(state_bag)
		return Status.FAILURE

	return _tick_selected_child(selected_index, context, state_bag)

func _tick_pinned_child(index: int, context: Dictionary, state_bag: Dictionary) -> Status:
	if index < 0 or index >= children.size():
		push_error("RS_BTUtilitySelector.tick: pinned child index %d is out of range" % index)
		_clear_local_state(state_bag)
		return Status.FAILURE

	var child: RS_BTNode = children[index]
	if child == null:
		push_error("RS_BTUtilitySelector.tick: child at index %d is null" % index)
		_clear_local_state(state_bag)
		return Status.FAILURE

	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.RUNNING:
		_set_running_child_index(state_bag, index)
		return Status.RUNNING
	if child_status == Status.SUCCESS or child_status == Status.FAILURE:
		_clear_local_state(state_bag)
		return child_status

	push_error("RS_BTUtilitySelector.tick: child returned invalid status %s" % str(child_status))
	_clear_local_state(state_bag)
	return Status.FAILURE

func _select_best_child_index(context: Dictionary) -> int:
	var best_index: int = -1
	var best_score: float = 0.0

	for index in range(children.size()):
		var child: RS_BTNode = children[index]
		if child == null:
			push_error("RS_BTUtilitySelector.tick: child at index %d is null" % index)
			continue

		var score: float = _score_child(index, context)
		if score <= 0.0:
			continue
		if score > best_score:
			best_score = score
			best_index = index

	return best_index

func _score_child(index: int, context: Dictionary) -> float:
	if index < 0 or index >= _scorer_callables.size():
		return 0.0

	var scorer: Callable = _scorer_callables[index]
	if scorer.is_null():
		return 0.0

	var score_variant: Variant = scorer.call(context)
	return float(score_variant)

func _tick_selected_child(index: int, context: Dictionary, state_bag: Dictionary) -> Status:
	var child: RS_BTNode = children[index]
	if child == null:
		push_error("RS_BTUtilitySelector.tick: child at index %d is null" % index)
		_clear_local_state(state_bag)
		return Status.FAILURE

	var child_status: int = child.tick(context, state_bag)
	if child_status == Status.RUNNING:
		_set_running_child_index(state_bag, index)
		return Status.RUNNING
	if child_status == Status.SUCCESS or child_status == Status.FAILURE:
		_clear_local_state(state_bag)
		return child_status

	push_error("RS_BTUtilitySelector.tick: child returned invalid status %s" % str(child_status))
	_clear_local_state(state_bag)
	return Status.FAILURE

func _set_running_child_index(state_bag: Dictionary, index: int) -> void:
	state_bag[node_id] = {
		STATE_KEY_RUNNING_CHILD_INDEX: index,
	}

func _get_running_child_index(state_bag: Dictionary) -> int:
	var local_state: Dictionary = _get_local_state(state_bag)
	var index_variant: Variant = local_state.get(STATE_KEY_RUNNING_CHILD_INDEX, -1)
	return int(index_variant)

func _clear_local_state(state_bag: Dictionary) -> void:
	state_bag.erase(node_id)

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return state_variant as Dictionary
	return {}

func _coerce_scorer_callables(value: Variant) -> Array[Callable]:
	var coerced: Array[Callable] = []
	if not (value is Array):
		return coerced
	for callable_variant in value as Array:
		if callable_variant is Callable:
			coerced.append(callable_variant)
	return coerced

func _capture_callable_owners(callables: Array[Callable]) -> Array[Variant]:
	var owners: Array[Variant] = []
	for scorer in callables:
		if scorer.is_null():
			owners.append(null)
			continue
		owners.append(scorer.get_object())
	return owners
