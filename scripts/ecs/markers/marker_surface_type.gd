@icon("res://resources/editor_icons/component.svg")
extends Node
class_name Marker_SurfaceType

const C_SURFACE_DETECTOR := preload("res://scripts/ecs/components/c_surface_detector_component.gd")

@export var surface_type: int = C_SURFACE_DETECTOR.SurfaceType.DEFAULT

func get_surface_type() -> int:
	return surface_type
