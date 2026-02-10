@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_InteractionConfig

const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")

@export var interaction_id: StringName = StringName("")
@export var enabled_by_default: bool = true
@export var trigger_settings: RS_SceneTriggerSettings = RS_SCENE_TRIGGER_SETTINGS.new()
@export var interaction_hint_enabled: bool = false
@export var interaction_hint_icon: Texture2D = null
@export var interaction_hint_offset: Vector3 = Vector3(0.0, 1.8, 0.0)
@export_range(0.1, 4.0, 0.05, "or_greater") var interaction_hint_scale: float = 1.0
