@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_DebugInitialState

const U_DebugReducer := preload("res://scripts/state/reducers/u_debug_reducer.gd")

@export var debug_settings: Dictionary = {}

func _init() -> void:
	if debug_settings.is_empty():
		debug_settings = U_DebugReducer.get_default_debug_state()

func to_dictionary() -> Dictionary:
	var defaults := U_DebugReducer.get_default_debug_state()
	if debug_settings == null:
		return defaults

	var merged := defaults.duplicate(true)
	if debug_settings.is_empty():
		return merged

	for key in debug_settings.keys():
		merged[key] = _deep_copy(debug_settings[key])

	return merged

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
