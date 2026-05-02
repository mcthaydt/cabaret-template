extends RefCounted
class_name U_SettingsReducer

const INPUT_REDUCER := preload("res://scripts/core/state/reducers/u_input_reducer.gd")

## Settings slice reducer
##
## Wraps U_InputReducer to keep persistent input settings in the state store.

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var current_state: Dictionary = {}
	if state != null:
		current_state = state.duplicate(true)
	var current_input_settings: Dictionary = _get_input_settings(current_state)
	var reduced: Variant = INPUT_REDUCER.reduce_input_settings(current_input_settings, action)
	if reduced == null:
		return state

	current_state["input_settings"] = reduced
	return current_state

static func _get_input_settings(state: Dictionary) -> Dictionary:
	if state != null and state.has("input_settings") and state["input_settings"] is Dictionary:
		return (state["input_settings"] as Dictionary).duplicate(true)
	return INPUT_REDUCER.get_default_input_settings_state()
