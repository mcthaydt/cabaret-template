@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_PostProcessingPreset

## Post-processing preset definition for Display Manager.
##
## Stores intensity values for post-processing effects.

@export var preset_name: String = ""
@export var display_name: String = ""
@export var sort_order: int = 0

@export_group("Effect Intensities")
@export_range(0.0, 1.0, 0.01) var film_grain_intensity: float = 0.1
@export_range(0.0, 1.0, 0.01) var dither_intensity: float = 0.5
@export_range(0.0, 1.0, 0.01) var line_mask_intensity: float = 0.0
@export_range(60.0, 1080.0, 10.0) var scanline_count: float = 480.0
