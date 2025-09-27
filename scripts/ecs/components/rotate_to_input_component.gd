extends ECSComponent

class_name RotateToInputComponent

const COMPONENT_TYPE := StringName("RotateToInputComponent")

@export var turn_speed_degrees: float = 720.0
@export_node_path("Node3D") var target_node_path: NodePath
@export_node_path("Node") var input_component_path: NodePath

func _init() -> void:
    component_type = COMPONENT_TYPE

func get_target_node() -> Node3D:
    if target_node_path.is_empty():
        return null
    return get_node_or_null(target_node_path)

func get_input_component():
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path)
