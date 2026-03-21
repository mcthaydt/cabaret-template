@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_RegionVisibilitySettings

@export var fade_speed: float = 3.0
@export var min_alpha: float = 0.0
@export var aabb_grow: float = 2.0
@export var aabb_vertical_shrink: float = 0.5

func get_resolved_values() -> Dictionary:
	return {
		"fade_speed": maxf(fade_speed, 0.0),
		"min_alpha": clampf(min_alpha, 0.0, 1.0),
		"aabb_grow": maxf(aabb_grow, 0.0),
		"aabb_vertical_shrink": maxf(aabb_vertical_shrink, 0.0),
	}
