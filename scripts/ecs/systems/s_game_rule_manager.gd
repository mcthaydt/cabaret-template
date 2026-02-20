@icon("res://assets/editor_icons/icn_system.svg")
extends BaseQBRuleManager
class_name S_GameRuleManager

const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/game/cfg_checkpoint_rule.tres"),
	preload("res://resources/qb/game/cfg_victory_rule.tres"),
]

func get_default_rule_definitions() -> Array:
	return DEFAULT_RULE_DEFINITIONS.duplicate()
