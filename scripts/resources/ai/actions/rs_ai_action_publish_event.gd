@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/interfaces/i_ai_action.gd"
class_name RS_AIActionPublishEvent

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

@export var event_name: StringName
@export var payload: Dictionary = {}

func start(_context: Dictionary, task_state: Dictionary) -> void:
	if bool(task_state.get("published", false)):
		return

	if not event_name.is_empty():
		U_ECS_EVENT_BUS.publish(event_name, payload.duplicate(true))

	task_state["published"] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get("published", false))
