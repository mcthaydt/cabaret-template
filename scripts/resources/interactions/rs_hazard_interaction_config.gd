@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/interactions/rs_interaction_config.gd"
class_name RS_HazardInteractionConfig

@export var damage_amount: float = 25.0
@export var is_instant_death: bool = false
@export var damage_cooldown: float = 1.0
