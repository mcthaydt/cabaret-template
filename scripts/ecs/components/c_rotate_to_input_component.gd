@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_RotateToInputComponent

const COMPONENT_TYPE := StringName("C_RotateToInputComponent")

@export var settings: RS_RotateToInputSettings
@export_node_path("Node3D") var target_node_path: NodePath

var _rotation_velocity: float = 0.0

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_RotateToInputComponent missing settings; assign an RS_RotateToInputSettings resource.")
		return false
	return true

func get_target_node() -> Node3D:
	if target_node_path.is_empty():
		return null
	return get_node_or_null(target_node_path)

func set_rotation_velocity(value: float) -> void:
	_rotation_velocity = value

func get_rotation_velocity() -> float:
	return _rotation_velocity

func reset_rotation_state() -> void:
	_rotation_velocity = 0.0
