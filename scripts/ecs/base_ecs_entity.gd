@icon("res://resources/editor_icons/entities.svg")
extends Node3D
class_name BaseECSEntity

const META_ENTITY_ROOT := StringName("_ecs_entity_root")
const ENTITY_GROUP := StringName("ecs_entity")

@export var add_legacy_group: bool = false

func _ready() -> void:
	set_meta(META_ENTITY_ROOT, self)
	if add_legacy_group and not is_in_group(ENTITY_GROUP):
		add_to_group(ENTITY_GROUP)
