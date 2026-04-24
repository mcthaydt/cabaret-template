@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_CharacterLightingConfig

@export var mobile_tick_interval: int = 3
@export var default_profile: Resource = null
@export var default_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var default_intensity: float = 1.0
@export var default_blend_smoothing: float = 0.15


func get_default_profile_values() -> Dictionary:
	if default_profile != null and default_profile.has_method("get_resolved_values"):
		var resolved_variant: Variant = default_profile.call("get_resolved_values")
		if resolved_variant is Dictionary:
			return (resolved_variant as Dictionary).duplicate(true)
	return {
		"tint": default_tint,
		"intensity": maxf(default_intensity, 0.0),
		"blend_smoothing": clampf(default_blend_smoothing, 0.0, 1.0),
	}

