@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionWait

@export var duration: float = 1.0

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.ELAPSED] = 0.0

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AITaskStateKeys.ELAPSED, 0.0)
	task_state[U_AITaskStateKeys.ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = task_state.get(U_AITaskStateKeys.ELAPSED, 0.0)
	return elapsed >= maxf(duration, 0.0)