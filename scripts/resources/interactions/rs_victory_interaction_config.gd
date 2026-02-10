@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/interactions/rs_interaction_config.gd"
class_name RS_VictoryInteractionConfig

const C_VICTORY_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")

@export var objective_id: StringName = StringName("")
@export var area_id: String = ""
@export var victory_type: int = C_VICTORY_TRIGGER_COMPONENT.VictoryType.LEVEL_COMPLETE
@export var trigger_once: bool = true
