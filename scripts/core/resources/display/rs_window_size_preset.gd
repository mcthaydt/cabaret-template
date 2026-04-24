@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_WindowSizePreset

## Window size preset definition for Display Manager.
##
## Used by display option catalog + UI to provide data-driven window sizes.

@export var preset_id: StringName = &""
@export var size: Vector2i = Vector2i(0, 0)
@export var label: String = ""
@export var sort_order: int = 0
