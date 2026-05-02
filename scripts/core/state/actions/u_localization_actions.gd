extends RefCounted
class_name U_LocalizationActions

## Localization Actions (Phase 0 - Task 0B.2)
##
## Action creators for Localization slice mutations. All actions are registered
## with U_ActionRegistry for validation and dispatched via M_StateStore.


const ACTION_SET_LOCALE := StringName("localization/set_locale")
const ACTION_SET_DYSLEXIA_FONT_ENABLED := StringName("localization/set_dyslexia_font_enabled")
const ACTION_SET_UI_SCALE_OVERRIDE := StringName("localization/set_ui_scale_override")
const ACTION_MARK_LANGUAGE_SELECTED := StringName("localization/mark_language_selected")


static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_LOCALE)
	U_ActionRegistry.register_action(ACTION_SET_DYSLEXIA_FONT_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_UI_SCALE_OVERRIDE)
	U_ActionRegistry.register_action(ACTION_MARK_LANGUAGE_SELECTED)


static func set_locale(locale: StringName) -> Dictionary:
	return {"type": ACTION_SET_LOCALE, "payload": {"locale": locale}}


static func set_dyslexia_font_enabled(enabled: bool) -> Dictionary:
	return {"type": ACTION_SET_DYSLEXIA_FONT_ENABLED, "payload": {"enabled": enabled}}


static func set_ui_scale_override(scale: float) -> Dictionary:
	return {"type": ACTION_SET_UI_SCALE_OVERRIDE, "payload": {"scale": scale}}


static func mark_language_selected() -> Dictionary:
	return {"type": ACTION_MARK_LANGUAGE_SELECTED, "payload": {}, "immediate": true}
