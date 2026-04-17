extends RefCounted
class_name U_LocalizationSelectors

## Localization Selectors (Phase 0 - Task 0D.2)
##
## Pure selector functions for reading Localization slice state.
## Provides safe defaults when localization slice or fields are missing.


static func get_locale(state: Dictionary) -> StringName:
	return StringName(_get_localization_slice(state).get("current_locale", &"en"))


static func is_dyslexia_font_enabled(state: Dictionary) -> bool:
	return bool(_get_localization_slice(state).get("dyslexia_font_enabled", false))


static func get_ui_scale_override(state: Dictionary) -> float:
	return float(_get_localization_slice(state).get("ui_scale_override", 1.0))


static func has_selected_language(state: Dictionary) -> bool:
	return bool(_get_localization_slice(state).get("has_selected_language", false))


## Returns the entire localization slice for hash-based change detection.
static func get_localization_settings(state: Dictionary) -> Dictionary:
	return _get_localization_slice(state)

static func _get_localization_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	# If state has a "localization" key, extract the nested slice (full state passed)
	var slice: Variant = state.get("localization", null)
	if slice is Dictionary:
		return slice as Dictionary
	# If state has "current_locale" key, it's already the localization slice (backward compat)
	if state.has("current_locale"):
		return state
	return {}
