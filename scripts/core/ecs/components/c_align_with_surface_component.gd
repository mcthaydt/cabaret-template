@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_AlignWithSurfaceComponent

const COMPONENT_TYPE := StringName("C_AlignWithSurfaceComponent")

@export var settings: RS_AlignSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node3D") var visual_alignment_path: NodePath

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_AlignWithSurfaceComponent missing settings; assign an RS_AlignSettings resource.")
		return false
	return true

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
