extends ECSComponent

class_name FloatingComponent

const COMPONENT_TYPE := StringName('FloatingComponent')

@export var hover_height: float = 1.5
@export var hover_frequency: float = 3.0
@export var damping_ratio: float = 1.0
@export var max_up_speed: float = 20.0
@export var max_down_speed: float = 30.0
@export var fall_gravity: float = 30.0
@export var height_tolerance: float = 0.05
@export var settle_speed_tolerance: float = 0.1
@export var align_to_normal: bool = true
@export_node_path('CharacterBody3D') var character_body_path: NodePath
@export_node_path('Node3D') var raycast_root_path: NodePath

var is_supported: bool = false
var _last_support_time: float = -INF

func _init() -> void:
	component_type = COMPONENT_TYPE

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

func has_recent_support(current_time: float, tolerance: float) -> bool:
	if is_supported:
		return true
	return current_time - _last_support_time <= tolerance
