@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_CharacterLightingProfile

@export var profile_id: StringName = StringName("")
@export var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 8.0, 0.01) var intensity: float = 1.0
@export_range(0.0, 1.0, 0.01) var blend_smoothing: float = 0.15

const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 8.0
const MIN_SMOOTHING := 0.0
const MAX_SMOOTHING := 1.0

func get_clamped_intensity() -> float:
	return clampf(intensity, 0.0, 8.0)

func get_clamped_smoothing() -> float:
	return clampf(blend_smoothing, MIN_SMOOTHING, MAX_SMOOTHING)

func get_resolved_values() -> Dictionary:
	return {
		"profile_id": profile_id,
		"tint": tint,
		"intensity": clampf(intensity, MIN_INTENSITY, MAX_INTENSITY),
		"blend_smoothing": clampf(blend_smoothing, MIN_SMOOTHING, MAX_SMOOTHING),
	}
