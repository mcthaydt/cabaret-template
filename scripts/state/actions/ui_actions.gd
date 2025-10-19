extends RefCounted

class_name UiActions

const ACTION_UTILS := preload("res://scripts/state/u_action_utils.gd")

static func open_menu(menu) -> Dictionary:
	var menu_name: StringName = menu if typeof(menu) == TYPE_STRING_NAME else StringName(str(menu))
	return ACTION_UTILS.create_action("ui/open_menu", menu_name)

static func close_menu() -> Dictionary:
	return ACTION_UTILS.create_action("ui/close_menu")

static func set_setting(key, value) -> Dictionary:
	var payload: Dictionary = {
		"key": str(key),
		"value": value,
	}
	return ACTION_UTILS.create_action("ui/set_setting", payload)
