@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_WallVisibilityConfig

@export var fade_dot_threshold: float = 0.3
@export var fade_speed: float = 4.0
@export var min_alpha: float = 0.05
@export var clip_height_offset: float = 1.5
@export var room_aabb_margin: float = 2.0
@export var corridor_occlusion_margin: float = 2.0
@export var invalidate_interval: int = 30
@export var mobile_tick_interval: int = 4
@export var roof_normal_dot_min: float = 0.9
@export var roof_height_margin: float = 0.5

