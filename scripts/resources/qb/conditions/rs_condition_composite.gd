@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_condition.gd"
class_name RS_ConditionComposite

const MAX_NESTING_DEPTH: int = 8
const CONTEXT_DEPTH_KEY := "_composite_depth"

enum CompositeMode {
	ALL = 0,
	ANY = 1,
}

@export var mode: CompositeMode = CompositeMode.ALL
@export var children: Array[Resource] = []

func _evaluate_raw(context: Dictionary) -> float:
	var current_depth: int = _read_depth(context)
	if current_depth >= MAX_NESTING_DEPTH:
		return 0.0
	if children.is_empty():
		return 0.0

	var child_context: Dictionary = context.duplicate(false)
	child_context[CONTEXT_DEPTH_KEY] = current_depth + 1

	match mode:
		CompositeMode.ALL:
			return _evaluate_all(child_context)
		CompositeMode.ANY:
			return _evaluate_any(child_context)
		_:
			return 0.0

func _evaluate_all(context: Dictionary) -> float:
	var score: float = 1.0
	for child_resource in children:
		var child: Variant = child_resource
		if child == null:
			return 0.0
		if not child.has_method("evaluate"):
			return 0.0
		score *= _to_score(child.evaluate(context))
		if score <= 0.0:
			return 0.0
	return clampf(score, 0.0, 1.0)

func _evaluate_any(context: Dictionary) -> float:
	var best_score: float = 0.0
	for child_resource in children:
		var child: Variant = child_resource
		if child == null:
			continue
		if not child.has_method("evaluate"):
			continue
		var child_score: float = _to_score(child.evaluate(context))
		if child_score > best_score:
			best_score = child_score
	return clampf(best_score, 0.0, 1.0)

func _to_score(value: Variant) -> float:
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return 0.0

func _read_depth(context: Dictionary) -> int:
	var depth_variant: Variant = context.get(CONTEXT_DEPTH_KEY, 0)
	if depth_variant is int:
		return max(depth_variant, 0)
	if depth_variant is float:
		return max(int(depth_variant), 0)
	return 0
