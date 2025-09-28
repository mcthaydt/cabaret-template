extends ECSComponent

class_name MovementComponent

const COMPONENT_TYPE := StringName("MovementComponent")

@export var max_speed: float = 6.0
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
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath
@export_node_path("Node") var support_component_path: NodePath

var _horizontal_dynamics_velocity: Vector2 = Vector2.ZERO
var _last_debug_snapshot: Dictionary = {}

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

func get_support_component() -> FloatingComponent:
    if support_component_path.is_empty():
        return null
    return get_node_or_null(support_component_path) as FloatingComponent

func get_horizontal_dynamics_velocity() -> Vector2:
    return _horizontal_dynamics_velocity

func set_horizontal_dynamics_velocity(value: Vector2) -> void:
    _horizontal_dynamics_velocity = value

func reset_dynamics_state() -> void:
    _horizontal_dynamics_velocity = Vector2.ZERO

func update_debug_snapshot(snapshot: Dictionary) -> void:
    _last_debug_snapshot = snapshot.duplicate(true)

func get_last_debug_snapshot() -> Dictionary:
    return _last_debug_snapshot.duplicate(true)
