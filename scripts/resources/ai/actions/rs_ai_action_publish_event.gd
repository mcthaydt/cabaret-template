@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionPublishEvent

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

@export var event_name: StringName
@export var payload: Dictionary = {}

func start(_context: Dictionary, task_state: Dictionary) -> void:
	if bool(task_state.get(U_AI_TASK_STATE_KEYS.PUBLISHED, false)):
		return

	if not event_name.is_empty():
		U_ECS_EVENT_BUS.publish(event_name, payload.duplicate(true))

	task_state[U_AI_TASK_STATE_KEYS.PUBLISHED] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AI_TASK_STATE_KEYS.PUBLISHED, false))