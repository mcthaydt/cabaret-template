extends RefCounted
class_name U_DebugActions


const ACTION_SET_DISABLE_TOUCHSCREEN := StringName("debug/set_disable_touchscreen")
const ACTION_SET_SKIP_SPLASH := StringName("debug/set_skip_splash")
const ACTION_SET_SKIP_LANGUAGE_SELECTION := StringName("debug/set_skip_language_selection")
const ACTION_SET_SKIP_MAIN_MENU := StringName("debug/set_skip_main_menu")
const ACTION_SET_BOOT_SKIPS_CONSUMED := StringName("debug/set_boot_skips_consumed")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_DISABLE_TOUCHSCREEN)
	U_ActionRegistry.register_action(ACTION_SET_SKIP_SPLASH)
	U_ActionRegistry.register_action(ACTION_SET_SKIP_LANGUAGE_SELECTION)
	U_ActionRegistry.register_action(ACTION_SET_SKIP_MAIN_MENU)
	U_ActionRegistry.register_action(ACTION_SET_BOOT_SKIPS_CONSUMED)

static func set_disable_touchscreen(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DISABLE_TOUCHSCREEN,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

static func set_skip_splash(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SKIP_SPLASH,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

static func set_skip_language_selection(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SKIP_LANGUAGE_SELECTION,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

static func set_skip_main_menu(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SKIP_MAIN_MENU,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

static func set_boot_skips_consumed(consumed: bool) -> Dictionary:
	return {
		"type": ACTION_SET_BOOT_SKIPS_CONSUMED,
		"payload": {
			"enabled": consumed
		},
		"immediate": true
	}
