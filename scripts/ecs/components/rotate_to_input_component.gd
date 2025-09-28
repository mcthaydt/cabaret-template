extends ECSComponent

class_name RotateToInputComponent

const COMPONENT_TYPE := StringName("RotateToInputComponent")

@export var turn_speed_degrees := 720.0 : set = set_turn_speed_degrees, get = get_turn_speed_degrees
@export var max_turn_speed_degrees: float = 720.0
@export var use_second_order: bool = false
@export var rotation_frequency: float = 2.0
@export var rotation_damping: float = 0.7
@export_node_path("Node3D") var target_node_path: NodePath
@export_node_path("Node") var input_component_path: NodePath

var _turn_speed_internal: float = 720.0
var _rotation_velocity: float = 0.0

func _init() -> void:
    component_type = COMPONENT_TYPE
    set_turn_speed_degrees(_turn_speed_internal)

func get_target_node() -> Node3D:
    if target_node_path.is_empty():
        return null
    return get_node_or_null(target_node_path)

func get_input_component():
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path)

func set_turn_speed_degrees(value: float) -> void:
    _turn_speed_internal = value
    max_turn_speed_degrees = value

func get_turn_speed_degrees() -> float:
    return _turn_speed_internal

func set_rotation_velocity(value: float) -> void:
    _rotation_velocity = value

func get_rotation_velocity() -> float:
    return _rotation_velocity

func reset_rotation_state() -> void:
    _rotation_velocity = 0.0
