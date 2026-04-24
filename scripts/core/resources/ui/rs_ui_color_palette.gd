@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_UIColorPalette

## UI color palette resource for accessibility-aware theming.

@export var palette_id: StringName = StringName("normal")

@export_group("Core")
@export var primary: Color = Color(0.2, 0.55, 0.9, 1.0)
@export var secondary: Color = Color(0.9, 0.35, 0.2, 1.0)

@export_group("Status")
@export var success: Color = Color(0.2, 0.75, 0.3, 1.0)
@export var warning: Color = Color(0.95, 0.76, 0.2, 1.0)
@export var danger: Color = Color(0.9, 0.2, 0.2, 1.0)
@export var info: Color = Color(0.2, 0.7, 0.8, 1.0)

@export_group("Text")
@export var background: Color = Color(0.08, 0.09, 0.11, 1.0)
@export var text: Color = Color(0.95, 0.95, 0.95, 1.0)
