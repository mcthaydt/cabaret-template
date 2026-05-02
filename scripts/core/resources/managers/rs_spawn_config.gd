@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SpawnConfig

@export var ground_snap_max_distance: float = 8.0
@export var hover_snap_max_distance: float = 0.75
@export var spawn_condition_always: int = 0
@export var spawn_condition_checkpoint_only: int = 1
@export var spawn_condition_disabled: int = 2

