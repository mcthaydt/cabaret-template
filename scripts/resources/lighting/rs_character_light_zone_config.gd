@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_CharacterLightZoneConfig

const RS_CHARACTER_LIGHTING_PROFILE := preload("res://scripts/resources/lighting/rs_character_lighting_profile.gd")

enum ShapeType {
	BOX = 0,
	CYLINDER = 1,
}

const MIN_DIMENSION := 0.01

@export var shape_type: ShapeType = ShapeType.BOX
@export var zone_id: StringName = StringName("")
@export var local_offset: Vector3 = Vector3.ZERO
@export var box_size: Vector3 = Vector3(4.0, 3.0, 4.0)
@export_range(0.01, 128.0, 0.01, "or_greater") var cylinder_radius: float = 2.0
@export_range(0.01, 128.0, 0.01, "or_greater") var cylinder_height: float = 3.0
@export_range(0.0, 1.0, 0.01) var falloff: float = 0.5
@export_range(0.0, 1.0, 0.01) var blend_weight: float = 1.0
@export_range(-1000, 1000, 1) var priority: int = 0
@export var profile: Resource = null:
	get:
		return _profile
	set(value):
		if value != null and value.get_script() != RS_CHARACTER_LIGHTING_PROFILE:
			return
		_profile = value

var _profile: Resource = null

func get_resolved_values() -> Dictionary:
	var profile_snapshot: Dictionary = {}
	if _profile != null:
		var typed_profile := _profile as RS_CharacterLightingProfile
		if typed_profile != null:
			profile_snapshot = typed_profile.get_resolved_values().duplicate(true)

	return {
		"shape_type": shape_type,
		"zone_id": zone_id,
		"local_offset": local_offset,
		"box_size": _clamp_box_size(box_size),
		"cylinder_radius": maxf(cylinder_radius, MIN_DIMENSION),
		"cylinder_height": maxf(cylinder_height, MIN_DIMENSION),
		"falloff": clampf(falloff, 0.0, 1.0),
		"blend_weight": clampf(blend_weight, 0.0, 1.0),
		"priority": priority,
		"profile": profile_snapshot,
	}

func _clamp_box_size(value: Vector3) -> Vector3:
	return Vector3(
		maxf(value.x, MIN_DIMENSION),
		maxf(value.y, MIN_DIMENSION),
		maxf(value.z, MIN_DIMENSION)
	)
