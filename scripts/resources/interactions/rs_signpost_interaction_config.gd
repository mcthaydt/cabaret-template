@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/interactions/rs_interaction_config.gd"
class_name RS_SignpostInteractionConfig

@export_multiline var message: String = ""
@export var repeatable: bool = true
@export var interact_prompt: String = "Read"
