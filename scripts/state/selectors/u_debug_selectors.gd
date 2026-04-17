extends RefCounted
class_name U_DebugSelectors

static func get_debug_settings(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var debug_state: Variant = state.get("debug", {})
	if debug_state is Dictionary:
		return (debug_state as Dictionary).duplicate(true)
	return {}

static func is_touchscreen_disabled(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("disable_touchscreen", false))

static func should_skip_splash(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("skip_splash", false))

static func should_skip_language_selection(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("skip_language_selection", false))

static func should_skip_main_menu(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("skip_main_menu", false))

static func are_boot_skips_consumed(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("boot_skips_consumed", false))
