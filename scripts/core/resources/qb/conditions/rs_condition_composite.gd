@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/qb/rs_base_condition.gd"
class_name RS_ConditionComposite

const MAX_NESTING_DEPTH: int = 8
const CONTEXT_DEPTH_KEY := "_composite_depth"

enum CompositeMode {
	ALL = 0,
	ANY = 1,
}

var _children: Array[I_Condition] = []

@export var mode: CompositeMode = CompositeMode.ALL
@export var children: Array[I_Condition] = []:
	get:
		return _children
	set(value):
		_children = _sanitize_children(value)


func _sanitize_children(value: Variant) -> Array[I_Condition]:
	var sanitized: Array[I_Condition] = []
	if not (value is Array):
		return sanitized
	for child_variant in value as Array:
		if child_variant is I_Condition:
			sanitized.append(child_variant as I_Condition)
	return sanitized

func _evaluate_raw(context: Dictionary) -> float:
	var current_depth: int = _read_depth(context)
	if current_depth >= MAX_NESTING_DEPTH:
		return 0.0
	if _children.is_empty():
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
	for child in _children:
		if child == null:
			return 0.0
		score *= _to_score(child.evaluate(context))
		if score <= 0.0:
			return 0.0
	return clampf(score, 0.0, 1.0)

func _evaluate_any(context: Dictionary) -> float:
	var best_score: float = 0.0
	for child in _children:
		if child == null:
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
