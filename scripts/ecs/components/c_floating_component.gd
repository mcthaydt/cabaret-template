@icon("res://editor_icons/component.svg")
extends ECSComponent
class_name C_FloatingComponent

const COMPONENT_TYPE := StringName("C_FloatingComponent")

@export var settings: RS_FloatingSettings
@export_node_path('CharacterBody3D') var character_body_path: NodePath
@export_node_path('Node3D') var raycast_root_path: NodePath

var is_supported: bool = false
var _last_support_time: float = - INF
var _last_support_normal: Vector3 = Vector3.UP
var _last_support_normal_time: float = - INF

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_FloatingComponent missing settings; assign an RS_FloatingSettings resource.")
		return false
	return true

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path) as CharacterBody3D

func get_raycast_root() -> Node3D:
	if raycast_root_path.is_empty():
		return null
	return get_node_or_null(raycast_root_path) as Node3D

func get_raycast_nodes() -> Array:
	var rays: Array = []
	var root: Node3D = get_raycast_root()
	if root == null:
		return rays

	if root is RayCast3D:
		rays.append(root)

	for child in root.get_children():
		if child is RayCast3D:
			rays.append(child)

	return rays

func update_support_state(supported: bool, current_time: float) -> void:
	is_supported = supported
	if supported:
		_last_support_time = current_time

func reset_recent_support(current_time: float, grace_time: float) -> void:
	is_supported = false
	_last_support_time = current_time - grace_time - 0.01

func has_recent_support(current_time: float, tolerance: float) -> bool:
	if is_supported:
		return true
	return current_time - _last_support_time <= tolerance

func set_last_support_normal(normal: Vector3, current_time: float) -> void:
	if normal.length() > 0.0:
		_last_support_normal = normal.normalized()
		_last_support_normal_time = current_time

func get_recent_support_normal(current_time: float, tolerance: float) -> Vector3:
	if _last_support_normal_time == - INF:
		return Vector3.ZERO
	if current_time - _last_support_normal_time <= tolerance:
		return _last_support_normal
	return Vector3.ZERO
