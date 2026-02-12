@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_CharacterLightingProfile

@export var profile_id: StringName = StringName("")
@export var base_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 8.0, 0.01) var intensity: float = 1.0
@export_range(0.0, 1.0, 0.01) var blend_smoothing: float = 0.0

func get_clamped_intensity() -> float:
	return clampf(intensity, 0.0, 8.0)
