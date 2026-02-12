@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_CharacterLightZoneConfig

const RS_CHARACTER_LIGHTING_PROFILE := preload("res://scripts/resources/lighting/rs_character_lighting_profile.gd")

@export_enum("box", "cylinder") var shape_type: String = "box"
@export var zone_id: StringName = StringName("")
@export var local_offset: Vector3 = Vector3.ZERO
@export var box_size: Vector3 = Vector3(4.0, 3.0, 4.0)
@export_range(0.01, 128.0, 0.01, "or_greater") var cylinder_radius: float = 2.0
@export_range(0.01, 128.0, 0.01, "or_greater") var cylinder_height: float = 3.0
@export_range(0.0, 1.0, 0.01) var falloff: float = 0.5
@export_range(0.0, 1.0, 0.01) var weight: float = 1.0
@export_range(-1000, 1000, 1) var priority: int = 0
@export var profile: Resource = null:
	get:
		return _profile
	set(value):
		if value != null and value.get_script() != RS_CHARACTER_LIGHTING_PROFILE:
			return
		_profile = value

var _profile: Resource = null
