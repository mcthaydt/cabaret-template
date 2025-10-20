@icon("res://editor_icons/component.svg")
extends ECSComponent
class_name C_MovementComponent

const COMPONENT_TYPE := StringName("C_MovementComponent")

@export var settings: RS_MovementSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath
@export_node_path("Node") var support_component_path: NodePath
@export_node_path("Camera3D") var camera_node_path: NodePath

var _horizontal_dynamics_velocity: Vector2 = Vector2.ZERO
var _last_debug_snapshot: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	if settings == null:
		push_error("C_MovementComponent missing settings; assign an RS_MovementSettings resource.")
		set_process(false)
		set_physics_process(false)
		return
	super._ready()

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path)

func get_input_component() -> C_InputComponent:
	if input_component_path.is_empty():
		return null
	return get_node_or_null(input_component_path) as C_InputComponent

func get_support_component() -> C_FloatingComponent:
	if support_component_path.is_empty():
		return null
	return get_node_or_null(support_component_path) as C_FloatingComponent

func get_camera_node() -> Camera3D:
	if camera_node_path.is_empty():
		return null
	return get_node_or_null(camera_node_path) as Camera3D

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
