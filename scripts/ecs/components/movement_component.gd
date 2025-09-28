extends ECSComponent

class_name MovementComponent

const COMPONENT_TYPE := StringName("MovementComponent")

@export var max_speed: float = 6.0
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var use_second_order_dynamics: bool = true
@export var response_frequency: float = 1.0
@export var damping_ratio: float = 0.5
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath

var _horizontal_dynamics_velocity: Vector2 = Vector2.ZERO

func _init() -> void:
    component_type = COMPONENT_TYPE

func get_character_body() -> CharacterBody3D:
    if character_body_path.is_empty():
        return null
    return get_node_or_null(character_body_path)

func get_input_component():
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path)

func get_horizontal_dynamics_velocity() -> Vector2:
    return _horizontal_dynamics_velocity

func set_horizontal_dynamics_velocity(value: Vector2) -> void:
    _horizontal_dynamics_velocity = value

func reset_dynamics_state() -> void:
    _horizontal_dynamics_velocity = Vector2.ZERO
