@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_MovementComponent

const COMPONENT_TYPE := StringName("C_MovementComponent")
const U_NODE_FIND := preload("res://scripts/core/utils/ecs/u_node_find.gd")

@export var settings: RS_MovementSettings

var _horizontal_dynamics_velocity: Vector2 = Vector2.ZERO
var _last_debug_snapshot: Dictionary = {}
var _cached_body: CharacterBody3D = null

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_MovementComponent missing settings; assign an RS_MovementSettings resource.")
		return false
	return true

func get_character_body() -> CharacterBody3D:
	if _cached_body != null and is_instance_valid(_cached_body) and _cached_body.is_inside_tree():
		return _cached_body
	_cached_body = _locate_character_body()
	return _cached_body

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

func _locate_character_body() -> CharacterBody3D:
	var entity := ECS_UTILS.find_entity_root(self)
	if entity == null:
		return null
	return U_NODE_FIND.find_character_body_recursive(entity)
