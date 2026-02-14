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


static func _get_localization_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var slice: Variant = state.get("localization", {})
	if slice is Dictionary:
		return slice as Dictionary
	return {}
