@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_RoomFadeSettings

@export var fade_dot_threshold: float = 0.3
@export var fade_speed: float = 4.0
@export var min_alpha: float = 0.05

func get_resolved_values() -> Dictionary:
	return {
		"fade_dot_threshold": clampf(fade_dot_threshold, 0.0, 1.0),
		"fade_speed": maxf(fade_speed, 0.0),
		"min_alpha": clampf(min_alpha, 0.0, 1.0),
	}
