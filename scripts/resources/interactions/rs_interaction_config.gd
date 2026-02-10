@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_InteractionConfig

const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")

@export var interaction_id: StringName = StringName("")
@export var enabled_by_default: bool = true
@export var trigger_settings: RS_SceneTriggerSettings = RS_SCENE_TRIGGER_SETTINGS.new()
