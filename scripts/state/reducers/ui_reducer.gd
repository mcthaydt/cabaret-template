@icon("res://resources/editor_icons/reducer.svg")
extends RefCounted
class_name UiReducer

const CONSTANTS := preload("res://scripts/state/state_constants.gd")
const STATE_UTILS := preload("res://scripts/state/u_state_utils.gd")

static func get_slice_name() -> StringName:
	return StringName("ui")

static func get_initial_state() -> Dictionary:
	return {
		"active_menu": StringName(""),
		"history": [],
		"settings": {},
	}

static func get_persistable() -> bool:
	return false

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var normalized := _normalize_state(state)
	var action_type: StringName = action.get("type", StringName(""))

	match action_type:
		CONSTANTS.INIT_ACTION:
			return get_initial_state()
		StringName("ui/open_menu"):
			return _apply_open_menu(normalized, action)
		StringName("ui/close_menu"):
			return _apply_close_menu(normalized)
		StringName("ui/set_setting"):
			return _apply_set_setting(normalized, action)
		_:
			return normalized

static func _normalize_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		return get_initial_state()

	var history_variant: Variant = state.get("history", [])
	var settings_variant: Variant = state.get("settings", {})

	var history_copy: Array = []
	if typeof(history_variant) == TYPE_ARRAY:
		history_copy = STATE_UTILS.safe_duplicate(history_variant)

	var settings_copy: Dictionary = {}
	if typeof(settings_variant) == TYPE_DICTIONARY:
		settings_copy = STATE_UTILS.safe_duplicate(settings_variant)

	return {
		"active_menu": state.get("active_menu", StringName("")),
		"history": history_copy,
		"settings": settings_copy,
	}

static func _apply_open_menu(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	var menu_variant: Variant = action.get("payload", StringName(""))
	var menu_name: StringName = menu_variant if typeof(menu_variant) == TYPE_STRING_NAME else StringName(str(menu_variant))
	next["active_menu"] = menu_name
	var history: Array = STATE_UTILS.safe_duplicate(next.get("history", []))
	if !history.is_empty() and history.back() == menu_name:
		next["history"] = history
		return next
	history.append(menu_name)
	next["history"] = history
	return next

static func _apply_close_menu(state: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	next["active_menu"] = StringName("")
	return next

static func _apply_set_setting(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = STATE_UTILS.safe_duplicate(state)
	var settings: Dictionary = STATE_UTILS.safe_duplicate(next.get("settings", {}))
	var payload_variant: Variant = action.get("payload", {})
	if typeof(payload_variant) != TYPE_DICTIONARY:
		next["settings"] = settings
		return next
	var payload: Dictionary = payload_variant
	var key_variant: Variant = payload.get("key")
	if key_variant == null:
		next["settings"] = settings
		return next
	var key_string: Variant = key_variant
	var value_variant: Variant = payload.get("value")
	settings[key_string] = value_variant
	next["settings"] = settings
	return next
