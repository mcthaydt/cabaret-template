@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_BuildStage

@export var stage_id: StringName = &""

@export var required_materials: Dictionary = {}

@export_range(0.1, 600.0, 0.1, "or_greater") var build_seconds: float = 3.0

@export var visual_node_path: NodePath = ""