extends RefCounted
class_name U_DebugReducer


const DEFAULT_DEBUG_STATE := {
	"disable_touchscreen": false,
	"skip_splash": false,
	"skip_language_selection": false,
	"skip_main_menu": false,
	"boot_skips_consumed": false,
}

static func get_default_debug_state() -> Dictionary:
	return DEFAULT_DEBUG_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_DEBUG_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_DebugActions.ACTION_SET_DISABLE_TOUCHSCREEN:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"disable_touchscreen": enabled})
		U_DebugActions.ACTION_SET_SKIP_SPLASH:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"skip_splash": enabled})
		U_DebugActions.ACTION_SET_SKIP_LANGUAGE_SELECTION:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"skip_language_selection": enabled})
		U_DebugActions.ACTION_SET_SKIP_MAIN_MENU:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"skip_main_menu": enabled})
		U_DebugActions.ACTION_SET_BOOT_SKIPS_CONSUMED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"boot_skips_consumed": enabled})
		_:
			return null

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = _deep_copy(updates[key])
	return next

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
