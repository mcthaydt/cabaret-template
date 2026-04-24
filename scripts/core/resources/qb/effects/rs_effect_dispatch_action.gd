@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/qb/rs_base_effect.gd"
class_name RS_EffectDispatchAction

@export var action_type: StringName
@export var payload: Dictionary = {}

func execute(context: Dictionary) -> void:
	if action_type.is_empty():
		return

	var store: Variant = _get_dict_value_string_or_name(context, "state_store")
	if store == null:
		return
	if not (store is Object) or not store.has_method("dispatch"):
		return

	var action: Dictionary = {
		"type": action_type,
	}
	# Merge payload fields into action root (matching project action creator pattern)
	var payload_copy: Dictionary = payload.duplicate(true)
	for key in payload_copy:
		action[key] = payload_copy[key]
	store.call("dispatch", action)

func _get_dict_value_string_or_name(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null
