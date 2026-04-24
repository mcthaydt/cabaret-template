@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/interactions/rs_victory_interaction_config.gd"
class_name RS_EndgameGoalInteractionConfig

@export var required_area: String = "interior_house"

func _init() -> void:
	victory_type = C_VICTORY_TRIGGER_COMPONENT.VictoryType.GAME_COMPLETE
