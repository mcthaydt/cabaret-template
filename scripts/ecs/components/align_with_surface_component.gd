extends ECSComponent

class_name AlignWithSurfaceComponent

const COMPONENT_TYPE := StringName("AlignWithSurfaceComponent")

@export var settings: AlignSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node3D") var visual_alignment_path: NodePath
@export_node_path("Node") var floating_component_path: NodePath

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	if settings == null:
		push_error("AlignWithSurfaceComponent missing settings; assign an AlignSettings resource.")
		set_process(false)
		set_physics_process(false)
		return
	super._ready()

func get_component_type() -> StringName:
	return component_type

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path) as CharacterBody3D

func get_visual_node() -> Node3D:
	if visual_alignment_path.is_empty():
		return null
	return get_node_or_null(visual_alignment_path) as Node3D

func get_floating_component() -> FloatingComponent:
	if floating_component_path.is_empty():
		return null
	return get_node_or_null(floating_component_path) as FloatingComponent

func has_recent_support(current_time: float, tolerance: float) -> bool:
	var floating := get_floating_component()
	if floating == null:
		return false
	return floating.has_recent_support(current_time, tolerance)
