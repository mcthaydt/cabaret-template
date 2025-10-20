@icon("res://editor_icons/action.svg")
extends RefCounted
class_name GameActions

const ACTION_UTILS := preload("res://scripts/state/u_action_utils.gd")

static func add_score(amount: int) -> Dictionary:
	return ACTION_UTILS.create_action("game/add_score", int(amount))

static func set_score(amount: int) -> Dictionary:
	return ACTION_UTILS.create_action("game/set_score", int(amount))

static func level_up() -> Dictionary:
	return ACTION_UTILS.create_action("game/level_up")

static func unlock(ability) -> Dictionary:
	var ability_name: StringName = ability if typeof(ability) == TYPE_STRING_NAME else StringName(str(ability))
	return ACTION_UTILS.create_action("game/unlock", ability_name)
