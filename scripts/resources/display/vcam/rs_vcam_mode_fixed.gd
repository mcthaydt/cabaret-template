@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamModeFixed

const MIN_FOV: float = 1.0
const MAX_FOV: float = 179.0

@export var use_world_anchor: bool = true
@export var track_target: bool = false
@export var fov: float = 75.0
@export var tracking_damping: float = 5.0
@export var follow_offset: Vector3 = Vector3(0.0, 3.0, 5.0)
@export var use_path: bool = false
@export var path_max_speed: float = 10.0
@export var path_damping: float = 5.0

func get_resolved_values() -> Dictionary:
	return {
		"use_world_anchor": use_world_anchor,
		"track_target": track_target,
		"fov": clampf(fov, MIN_FOV, MAX_FOV),
		"tracking_damping": maxf(tracking_damping, 0.0),
		"follow_offset": follow_offset,
		"use_path": use_path,
		"path_max_speed": maxf(path_max_speed, 0.0),
		"path_damping": maxf(path_damping, 0.0),
	}
