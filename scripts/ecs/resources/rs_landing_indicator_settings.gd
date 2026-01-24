@icon("res://assets/editor_icons/utility.svg")
extends Resource

class_name RS_LandingIndicatorSettings

@export var indicator_height_offset: float = 0.05
@export var ground_plane_height: float = 0.0
@export var max_projection_distance: float = 10.0
@export var ray_origin_lift: float = 0.15
@export var align_to_hit_normal: bool = true
@export_range(0, 2, 1) var normal_axis: int = 2 # 0=X, 1=Y, 2=Z
@export var normal_axis_positive: bool = false # false means use negative axis (e.g., -Z for Sprite3D)
