@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SettingsInitialState

const INPUT_REDUCER := preload("res://scripts/state/reducers/u_input_reducer.gd")

## Initial state for the settings slice
##
## Currently only tracks input settings, but the slice is structured to host
## additional settings categories over time.

@export var input_settings: Dictionary = {}

func _init() -> void:
	if input_settings.is_empty():
		input_settings = INPUT_REDUCER.get_default_input_settings_state()

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	var defaults: Dictionary = INPUT_REDUCER.get_default_input_settings_state()
	var merged: Dictionary = defaults.duplicate(true)

	if input_settings != null and not input_settings.is_empty():
		for key in input_settings.keys():
			merged[key] = _deep_copy(input_settings[key])

	return {
		"input_settings": merged
	}

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
