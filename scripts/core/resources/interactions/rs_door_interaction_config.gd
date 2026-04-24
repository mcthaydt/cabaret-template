@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/interactions/rs_interaction_config.gd"
class_name RS_DoorInteractionConfig

const C_SCENE_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")

@export var door_id: StringName = StringName("")
@export var target_scene_id: StringName = StringName("")
@export var target_spawn_point: StringName = StringName("")
@export var trigger_mode: int = C_SCENE_TRIGGER_COMPONENT.TriggerMode.INTERACT
@export var cooldown_duration: float = 1.0
