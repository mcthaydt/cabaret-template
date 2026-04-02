@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/interfaces/i_ai_action.gd"
class_name RS_AIActionWait

@export var duration: float = 1.0

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state["elapsed"] = 0.0

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = 0.0
	var elapsed_variant: Variant = task_state.get("elapsed", 0.0)
	if elapsed_variant is float or elapsed_variant is int:
		elapsed = float(elapsed_variant)
	task_state["elapsed"] = elapsed + maxf(delta, 0.0)

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = 0.0
	var elapsed_variant: Variant = task_state.get("elapsed", 0.0)
	if elapsed_variant is float or elapsed_variant is int:
		elapsed = float(elapsed_variant)
	return elapsed >= maxf(duration, 0.0)
