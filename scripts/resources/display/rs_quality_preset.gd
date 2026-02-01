@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_QualityPreset

## Quality preset definition for Display Manager.
##
## Stores render-tuning options used by M_DisplayManager when applying presets.

@export var preset_name: String = ""
@export_enum("off", "low", "medium", "high") var shadow_quality: String = "medium"
@export_enum("none", "fxaa", "msaa_2x", "msaa_4x", "msaa_8x") var anti_aliasing: String = "fxaa"
@export var post_processing_enabled: bool = true
