@icon("res://editor_icons/action.svg")
extends RefCounted
class_name SessionActions

const ACTION_UTILS := preload("res://scripts/state/u_action_utils.gd")

static func set_slot(slot: int) -> Dictionary:
	return ACTION_UTILS.create_action("session/set_slot", int(slot))

static func set_last_saved_tick(tick: int) -> Dictionary:
	return ACTION_UTILS.create_action("session/set_last_saved_tick", int(tick))

static func set_flag(key, value) -> Dictionary:
	var normalized_key: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(str(key))
	var payload: Dictionary = {
		"key": normalized_key,
		"value": value,
	}
	return ACTION_UTILS.create_action("session/set_flag", payload)

static func clear_flag(key) -> Dictionary:
	var normalized_key: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(str(key))
	return ACTION_UTILS.create_action("session/clear_flag", normalized_key)
