@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_CameraStateConfig

@export var trauma_decay_rate: float = 2.0
@export var max_offset_x: float = 10.0
@export var max_offset_y: float = 10.0
@export var max_rotation_rad: float = 0.03
@export var shake_frequency: Vector3 = Vector3(17.0, 21.0, 13.0)
@export var shake_phase: Vector3 = Vector3(1.1, 2.3, 0.7)
@export var fov_min: float = 1.0
@export var fov_max: float = 179.0

