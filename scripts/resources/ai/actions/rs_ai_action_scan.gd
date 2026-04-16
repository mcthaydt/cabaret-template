@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionScan

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

@export var scan_duration: float = 2.0
@export var rotation_speed: float = 1.0

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AI_TASK_STATE_KEYS.SCAN_ELAPSED] = 0.0
	task_state[U_AI_TASK_STATE_KEYS.SCAN_ACTIVE] = true
	task_state[U_AI_TASK_STATE_KEYS.SCAN_ROTATION_SPEED] = rotation_speed

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AI_TASK_STATE_KEYS.SCAN_ELAPSED, 0.0)
	task_state[U_AI_TASK_STATE_KEYS.SCAN_ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = task_state.get(U_AI_TASK_STATE_KEYS.SCAN_ELAPSED, 0.0)
	var complete: bool = elapsed >= maxf(scan_duration, 0.0)
	if complete:
		task_state[U_AI_TASK_STATE_KEYS.SCAN_ACTIVE] = false
	return complete