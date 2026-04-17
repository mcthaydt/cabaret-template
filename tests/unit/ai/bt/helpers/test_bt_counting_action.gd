extends I_AIAction

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

const STATE_KEY_PROGRESS := &"helper_progress"

@export var ticks_until_complete: int = 2

var start_count: int = 0
var tick_count: int = 0
var is_complete_count: int = 0
var last_tick_saw_action_started: bool = false

func start(_context: Dictionary, task_state: Dictionary) -> void:
	start_count += 1
	task_state[STATE_KEY_PROGRESS] = 0

func tick(_context: Dictionary, task_state: Dictionary, _delta: float) -> void:
	tick_count += 1
	last_tick_saw_action_started = bool(task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false))
	var progress: int = int(task_state.get(STATE_KEY_PROGRESS, 0))
	task_state[STATE_KEY_PROGRESS] = progress + 1

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	is_complete_count += 1
	var target_ticks: int = maxi(ticks_until_complete, 1)
	var progress: int = int(task_state.get(STATE_KEY_PROGRESS, 0))
	return progress >= target_ticks
