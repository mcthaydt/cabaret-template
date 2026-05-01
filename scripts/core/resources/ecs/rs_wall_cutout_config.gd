@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_WallCutoutConfig

@export_group("Cone Shape")
@export var cone_near_radius: float = 0.5
@export var cone_far_radius: float = 2.5
@export var cone_falloff: float = 0.5

@export_group("Alpha")
@export var cone_min_alpha: float = 0.0
