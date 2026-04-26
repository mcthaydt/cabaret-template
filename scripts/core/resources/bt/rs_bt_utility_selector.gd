@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_composite.gd"
class_name RS_BTUtilitySelector

const STATE_KEY_RUNNING_CHILD_INDEX := &"running_child_index"
var _child_scorers: Array[Resource] = []

@export var child_scorers: Array[Resource] = []:
	get:
		return _child_scorers
	set(value):
		_child_scorers = _coerce_child_scorers(value)

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
	var should_trace: bool = _should_trace_selection(context)
	var debug_scores: Array[String] = []

	for index in range(children.size()):
		var child: RS_BTNode = children[index]
		if child == null:
			push_error("RS_BTUtilitySelector.tick: child at index %d is null" % index)
			continue

		var score: float = _score_child(index, context)
		if should_trace:
			debug_scores.append("%d:%0.2f" % [index, score])
		if score <= 0.0:
			continue
		if score > best_score:
			best_score = score
			best_index = index

	if should_trace:
		print("[BT_TRACE] entity=%s selector=%s selected=%d score=%0.2f child_scores=%s" % [
			_resolve_entity_id(context),
			_resolve_selector_label(),
			best_index,
			best_score,
			str(debug_scores),
		])

	return best_index

func _score_child(index: int, context: Dictionary) -> float:
	var child: RS_BTNode = children[index]
	if "scorer" in child:
		return _score_child_via_node_scorer(child, context)
	return _score_child_via_resource(index, context)

func _score_child_via_node_scorer(child: RS_BTNode, context: Dictionary) -> float:
	var scorer: Variant = child.get("scorer")
	if scorer == null or not (scorer is Resource):
		return 0.0
	var score_variant: Variant = (scorer as Resource).call("score", context)
	if score_variant is float or score_variant is int:
		return float(score_variant)
	push_error("RS_BTUtilitySelector.tick: node scorer returned non-numeric score %s" % str(score_variant))
	return 0.0

func _score_child_via_resource(index: int, context: Dictionary) -> float:
	if index < 0 or index >= _child_scorers.size():
		return 0.0

	var scorer: Resource = _child_scorers[index]
	if scorer == null:
		return 0.0

	var score_variant: Variant = scorer.call("score", context)
	if score_variant is float or score_variant is int:
		return float(score_variant)
	push_error("RS_BTUtilitySelector.tick: child scorer at index %d returned non-numeric score %s" % [index, str(score_variant)])
	return 0.0

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

func _coerce_child_scorers(value: Variant) -> Array[Resource]:
	var coerced: Array[Resource] = []
	if not (value is Array):
		return coerced
	for scorer_variant in value as Array:
		if scorer_variant is Resource:
			coerced.append(scorer_variant as Resource)
	return coerced

func _should_trace_selection(context: Dictionary) -> bool:
	return _resolve_entity_id(context) != StringName("")

func _resolve_entity_id(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = context.get("entity_id", context.get(&"entity_id", StringName()))
	if entity_id_variant is StringName:
		return entity_id_variant as StringName
	if entity_id_variant is String:
		return StringName(entity_id_variant as String)
	return StringName("")

func _resolve_selector_label() -> String:
	var label: String = resource_name.strip_edges()
	if label.is_empty():
		return "<unnamed_selector>"
	return label
