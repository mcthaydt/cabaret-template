@icon("res://assets/editor_icons/utility.svg")
extends Resource

class_name RS_MovementSettings

@export var max_speed: float = 6.0
@export var sprint_speed_multiplier: float = 1.5
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var use_second_order_dynamics: bool = true
@export var response_frequency: float = 1.0
@export var damping_ratio: float = 0.5
@export var grounded_damping_multiplier: float = 1.5
@export var air_damping_multiplier: float = 0.75
@export var grounded_friction: float = 30.0
@export var air_friction: float = 5.0
@export var strafe_friction_scale: float = 1.0
@export var forward_friction_scale: float = 1.0
@export var support_grace_time: float = 0.25
@export var air_control_scale: float = 0.3
@export var slope_limit_degrees: float = 50.0
