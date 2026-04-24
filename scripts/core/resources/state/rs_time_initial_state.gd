@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_TimeInitialState

@export_group("Transient")
@export var is_paused: bool = false
@export var active_channels: Array = []
@export var timescale: float = 1.0

@export_group("World Clock")
@export var world_hour: int = 8
@export var world_minute: int = 0
@export var world_total_minutes: float = 480.0
@export var world_day_count: int = 1
@export var world_time_speed: float = 1.0

@export_group("Derived")
@export var is_daytime: bool = true

func to_dictionary() -> Dictionary:
	return {
		"is_paused": is_paused,
		"active_channels": active_channels.duplicate(),
		"timescale": timescale,
		"world_hour": world_hour,
		"world_minute": world_minute,
		"world_total_minutes": world_total_minutes,
		"world_day_count": world_day_count,
		"world_time_speed": world_time_speed,
		"is_daytime": is_daytime,
	}
