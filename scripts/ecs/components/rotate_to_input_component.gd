extends ECSComponent

class_name RotateToInputComponent

const COMPONENT_TYPE := StringName("RotateToInputComponent")

@export var settings: RotateToInputSettings
@export_node_path("Node3D") var target_node_path: NodePath
@export_node_path("Node") var input_component_path: NodePath

var _rotation_velocity: float = 0.0

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	if settings == null:
		push_error("RotateToInputComponent missing settings; assign a RotateToInputSettings resource.")
		set_process(false)
		set_physics_process(false)
		return
	super._ready()

func get_target_node() -> Node3D:
	if target_node_path.is_empty():
		return null
	return get_node_or_null(target_node_path)

func get_input_component():
	if input_component_path.is_empty():
		return null
	return get_node_or_null(input_component_path)

func set_rotation_velocity(value: float) -> void:
	_rotation_velocity = value

func get_rotation_velocity() -> float:
	return _rotation_velocity

func reset_rotation_state() -> void:
	_rotation_velocity = 0.0
