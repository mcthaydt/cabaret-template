@icon("res://resources/editor_icons/utility.svg")
extends Resource

class_name RS_FloatingSettings

@export var hover_height: float = 1.5
@export var hover_frequency: float = 3.0
@export var damping_ratio: float = 1.0
@export var max_up_speed: float = 20.0
@export var max_down_speed: float = 30.0
@export var fall_gravity: float = 60.0
@export var height_tolerance: float = 0.12
@export var settle_speed_tolerance: float = 0.60
@export var align_to_normal: bool = true

# Edge protection settings
# When few rays hit (edge cases), relax support gating to avoid drop-offs.
@export var edge_protection_enabled: bool = true
@export var edge_distance_slop: float = 0.25  # extra allowable distance below target when hits are few
@export var edge_vel_tolerance_bonus: float = 0.40  # extra velN tolerance when hits are few
@export var edge_fallback_max_extra_vel: float = 0.25  # allow small additional velN for fallback keep-support

# Only align visuals/up-direction when enough rays hit to produce a stable normal
@export var min_hits_for_alignment: int = 2
