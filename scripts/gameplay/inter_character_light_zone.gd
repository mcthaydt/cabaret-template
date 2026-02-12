extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_CharacterLightZone

const RS_CHARACTER_LIGHT_ZONE_CONFIG := preload("res://scripts/resources/lighting/rs_character_light_zone_config.gd")

var _config: Resource = null

@export var config: Resource:
	get:
		return _config
	set(value):
		if value != null and value.get_script() != RS_CHARACTER_LIGHT_ZONE_CONFIG:
			return
		_config = value

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()

func get_zone_id() -> StringName:
	var typed := _get_typed_config()
	if typed == null:
		return StringName("")
	return typed.zone_id

func get_zone_priority() -> int:
	var typed := _get_typed_config()
	if typed == null:
		return 0
	return typed.priority

func get_zone_profile() -> Resource:
	var typed := _get_typed_config()
	if typed == null:
		return null
	return typed.profile

func get_influence_weight(_world_position: Vector3) -> float:
	var typed := _get_typed_config()
	if typed == null:
		return 0.0
	return typed.weight

func _get_typed_config() -> RS_CharacterLightZoneConfig:
	if _config == null:
		return null
	if _config.get_script() != RS_CHARACTER_LIGHT_ZONE_CONFIG:
		return null
	return _config as RS_CharacterLightZoneConfig
