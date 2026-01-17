@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_SpawnStateComponent

const COMPONENT_TYPE := StringName("C_SpawnStateComponent")

@export var is_physics_frozen: bool = false
@export var unfreeze_at_frame: int = -1
@export var suppress_landing_until_frame: int = -1
@export_node_path("CharacterBody3D") var character_body_path: NodePath

func _init() -> void:
	component_type = COMPONENT_TYPE
	name = "C_SpawnStateComponent"

func _register_with_manager() -> void:
	if not is_inside_tree():
		return
	super._register_with_manager()

func mark_frozen(unfreeze_frame: int = -1, suppress_landing_frame: int = -1) -> void:
	is_physics_frozen = true
	unfreeze_at_frame = unfreeze_frame
	suppress_landing_until_frame = suppress_landing_frame

func clear_spawn_state() -> void:
	is_physics_frozen = false
	unfreeze_at_frame = -1
	suppress_landing_until_frame = -1

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path) as CharacterBody3D
