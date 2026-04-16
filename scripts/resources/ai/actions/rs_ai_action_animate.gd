@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionAnimate

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

@export var animation_state: StringName

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AI_TASK_STATE_KEYS.ANIMATION_STATE] = animation_state
	task_state[U_AI_TASK_STATE_KEYS.ANIMATION_REQUESTED] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AI_TASK_STATE_KEYS.ANIMATION_REQUESTED, false))