@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_LUTDefinition

## LUT definition for display color grading.

@export var lut_id: StringName = StringName("")
@export var display_name: String = ""
@export var texture: Texture2D
