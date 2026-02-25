@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_GameRuleManager

const DEFAULT_RULE_DEFINITIONS: Array = []

func get_default_rule_definitions() -> Array:
	return DEFAULT_RULE_DEFINITIONS.duplicate()
