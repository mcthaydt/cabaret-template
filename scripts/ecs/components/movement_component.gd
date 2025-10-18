extends ECSComponent

class_name MovementComponent

const COMPONENT_TYPE := StringName("MovementComponent")

@export var settings: MovementSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath
@export_node_path("Node") var support_component_path: NodePath

var _horizontal_dynamics_velocity: Vector2 = Vector2.ZERO
var _last_debug_snapshot: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	if settings == null:
		push_error("MovementComponent missing settings; assign a MovementSettings resource.")
		set_process(false)
		set_physics_process(false)
		return
	super._ready()

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
