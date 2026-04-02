extends "res://scripts/interfaces/i_ai_action.gd"

static var call_log: Array = []

@export var label: String = ""
@export var ticks_to_complete: int = 1

var start_calls: int = 0
var tick_calls: int = 0
var complete_checks: int = 0

static func clear_call_log() -> void:
	call_log.clear()

func start(_context: Dictionary, task_state: Dictionary) -> void:
	start_calls += 1
	call_log.append("start:%s" % label)
	task_state["started"] = true

func tick(_context: Dictionary, task_state: Dictionary, _delta: float) -> void:
	tick_calls += 1
	call_log.append("tick:%s" % label)
	task_state["tick_calls"] = tick_calls

func is_complete(_context: Dictionary, _task_state: Dictionary) -> bool:
	complete_checks += 1
	return tick_calls >= max(1, ticks_to_complete)
