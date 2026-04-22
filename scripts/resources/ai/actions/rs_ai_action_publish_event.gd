@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionPublishEvent

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

@export var event_name: StringName
@export var payload: Dictionary = {}

func start(context: Dictionary, task_state: Dictionary) -> void:
	if bool(task_state.get(U_AITaskStateKeys.PUBLISHED, false)):
		return

	if not event_name.is_empty():
		U_ECS_EVENT_BUS.publish(event_name, payload.duplicate(true))
		print("[ACTION] %s PublishEvent → name=%s payload=%s" % [
			_resolve_entity_label(context),
			event_name,
			str(payload)
		])

	task_state[U_AITaskStateKeys.PUBLISHED] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.PUBLISHED, false))

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
