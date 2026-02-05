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
@export_range(0.0, 1.0, 0.01) var crt_scanline_intensity: float = 0.3
@export_range(0.0, 10.0, 0.1) var crt_curvature: float = 2.0
@export_range(0.0, 0.01, 0.0001) var crt_chromatic_aberration: float = 0.002
@export_range(0.0, 1.0, 0.01) var dither_intensity: float = 0.5
