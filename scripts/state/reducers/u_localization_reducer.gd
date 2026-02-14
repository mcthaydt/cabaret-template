extends RefCounted
class_name U_LocalizationReducer

## Localization Reducer (Phase 0 - Task 0C.2)
##
## Pure reducer for the localization slice. Immutably handles all
## localization/ actions. CJK locales auto-set ui_scale_override to 1.1.


const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]
const CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]
const CJK_SCALE_OVERRIDE: float = 1.1
const DEFAULT_SCALE_OVERRIDE: float = 1.0


static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName(""))
	var payload: Dictionary = action.get("payload", {})

	match action_type:
		U_LocalizationActions.ACTION_SET_LOCALE:
			var locale: StringName = payload.get("locale", &"en")
			if locale not in SUPPORTED_LOCALES:
				return state
			var scale: float = CJK_SCALE_OVERRIDE if locale in CJK_LOCALES else DEFAULT_SCALE_OVERRIDE
			return _with_values(state, {"current_locale": locale, "ui_scale_override": scale})

		U_LocalizationActions.ACTION_SET_DYSLEXIA_FONT_ENABLED:
			return _with_values(state, {"dyslexia_font_enabled": payload.get("enabled", false)})

		U_LocalizationActions.ACTION_SET_UI_SCALE_OVERRIDE:
			var scale: float = clampf(payload.get("scale", 1.0), 0.5, 2.0)
			return _with_values(state, {"ui_scale_override": scale})

	return state


static func _with_values(state: Dictionary, values: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	for key: String in values:
		new_state[key] = values[key]
	return new_state
