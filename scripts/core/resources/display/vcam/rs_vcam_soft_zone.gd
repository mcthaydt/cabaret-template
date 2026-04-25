@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamSoftZone

@export_range(0.0, 1.0, 0.01) var dead_zone_width: float = 0.1
@export_range(0.0, 1.0, 0.01) var dead_zone_height: float = 0.1
@export_range(0.0, 1.0, 0.01) var soft_zone_width: float = 0.4
@export_range(0.0, 1.0, 0.01) var soft_zone_height: float = 0.4
@export_range(0.0, 20.0, 0.01) var damping: float = 2.0
@export_range(0.0, 0.5, 0.001) var hysteresis_margin: float = 0.02

func get_resolved_values() -> Dictionary:
	var resolved_dead_zone_width: float = clampf(dead_zone_width, 0.0, 1.0)
	var resolved_dead_zone_height: float = clampf(dead_zone_height, 0.0, 1.0)
	var resolved_soft_zone_width: float = clampf(maxf(soft_zone_width, resolved_dead_zone_width), 0.0, 1.0)
	var resolved_soft_zone_height: float = clampf(maxf(soft_zone_height, resolved_dead_zone_height), 0.0, 1.0)

	return {
		"dead_zone_width": resolved_dead_zone_width,
		"dead_zone_height": resolved_dead_zone_height,
		"soft_zone_width": resolved_soft_zone_width,
		"soft_zone_height": resolved_soft_zone_height,
		"damping": maxf(damping, 0.0),
		"hysteresis_margin": maxf(hysteresis_margin, 0.0),
	}
