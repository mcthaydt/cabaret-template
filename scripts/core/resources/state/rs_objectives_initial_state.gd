@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_ObjectivesInitialState

## Initial state for objectives slice.

@export var statuses: Dictionary = {}
@export var active_set_id: StringName = StringName("")
@export var active_set_ids: Array[StringName] = []
@export var event_log: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {
		"statuses": statuses.duplicate(true),
		"active_set_id": active_set_id,
		"active_set_ids": active_set_ids.duplicate(true),
		"event_log": event_log.duplicate(true),
	}