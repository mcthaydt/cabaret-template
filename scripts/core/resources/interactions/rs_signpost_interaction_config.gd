@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/interactions/rs_interaction_config.gd"
class_name RS_SignpostInteractionConfig

@export_multiline var message: String = ""
@export var repeatable: bool = true
@export_range(0.1, 30.0, 0.1, "or_greater") var message_duration_sec: float = 3.0
@export var interact_prompt: String = "hud.interact_read"
