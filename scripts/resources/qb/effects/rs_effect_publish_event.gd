@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_effect.gd"
class_name RS_EffectPublishEvent

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

@export var event_name: StringName
@export var payload: Dictionary = {}
@export var inject_entity_id: bool = true

func execute(context: Dictionary) -> void:
	if event_name.is_empty():
		return

	var event_payload: Dictionary = payload.duplicate(true)
	var entity_id: Variant = _get_context_value(context, "entity_id")
	if inject_entity_id and entity_id != null and not event_payload.has("entity_id"):
		event_payload["entity_id"] = entity_id

	U_ECS_EVENT_BUS.publish(event_name, event_payload)

func _get_context_value(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null
