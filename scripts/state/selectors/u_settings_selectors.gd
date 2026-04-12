extends RefCounted
class_name U_SettingsSelectors

## Settings state slice selectors
##
## Pure selector functions for reading Settings slice state.
## Provides safe defaults when settings slice or fields are missing.

## Get the active input profile ID
static func get_active_profile_id(state: Dictionary) -> String:
	var input_settings := get_input_settings(state)
	return String(input_settings.get("active_profile_id", "default"))

## Get input settings dictionary
static func get_input_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = state.get("settings", {})
	if settings is Dictionary:
		var input: Variant = (settings as Dictionary).get("input_settings", {})
		if input is Dictionary:
			return input as Dictionary
	return {}

## Get gamepad settings dictionary (deep copy to prevent mutation)
static func get_gamepad_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = get_input_settings(state).get("gamepad_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

## Get mouse settings dictionary (deep copy to prevent mutation)
static func get_mouse_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = get_input_settings(state).get("mouse_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

## Get touchscreen settings dictionary (deep copy to prevent mutation)
static func get_touchscreen_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = get_input_settings(state).get("touchscreen_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

## Private: extract settings slice from full state
static func _get_settings_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	# If state has a "settings" key, extract the nested slice (full state passed)
	var settings: Variant = state.get("settings", null)
	if settings is Dictionary:
		return settings as Dictionary
	# If state has "input_settings" key, it's already a settings-like dict (backward compat)
	if state.has("input_settings"):
		return state
	return {}