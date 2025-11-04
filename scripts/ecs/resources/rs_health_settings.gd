@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_HealthSettings

## Resource configuring player health behavior.
## Shared between components/systems to keep tunables in one place.

@export var default_max_health: float = 100.0
@export var invincibility_duration: float = 1.0
@export var regen_enabled: bool = true
@export var regen_delay: float = 3.0
@export var regen_rate: float = 10.0
@export var death_animation_duration: float = 2.5

func duplicate_settings() -> Dictionary:
	return {
		"default_max_health": default_max_health,
		"invincibility_duration": invincibility_duration,
		"regen_enabled": regen_enabled,
		"regen_delay": regen_delay,
		"regen_rate": regen_rate,
		"death_animation_duration": death_animation_duration
	}
