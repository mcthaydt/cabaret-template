@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_DisplayInitialState

## Display Initial State Resource (Phase 0 - Task 0A.2)
##
## Defines default display settings for the display slice.

@export_group("Graphics")
@export var window_size_preset: String = "1920x1080"
@export_enum("windowed", "fullscreen", "borderless") var window_mode: String = "windowed"
@export var vsync_enabled: bool = true
@export_enum("low", "medium", "high", "ultra") var quality_preset: String = "high"

@export_group("Post-Processing")
# Note: Effect order is fixed internally (Film Grain -> Outline -> Dither -> LUT), not user-configurable.
@export var film_grain_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var film_grain_intensity: float = 0.1
@export var outline_enabled: bool = false
@export_range(1, 5, 1) var outline_thickness: int = 2
@export var outline_color: String = "000000"
@export var dither_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var dither_intensity: float = 0.5
@export_enum("bayer", "noise") var dither_pattern: String = "bayer"
@export var lut_enabled: bool = false
@export var lut_resource: String = ""
@export_range(0.0, 1.0, 0.05) var lut_intensity: float = 1.0

@export_group("UI")
@export_range(0.8, 1.3, 0.1) var ui_scale: float = 1.0

@export_group("Accessibility")
@export_enum("normal", "deuteranopia", "protanopia", "tritanopia") var color_blind_mode: String = "normal"
@export var high_contrast_enabled: bool = false
@export var color_blind_shader_enabled: bool = false

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"window_size_preset": window_size_preset,
		"window_mode": window_mode,
		"vsync_enabled": vsync_enabled,
		"quality_preset": quality_preset,
		"film_grain_enabled": film_grain_enabled,
		"film_grain_intensity": film_grain_intensity,
		"outline_enabled": outline_enabled,
		"outline_thickness": outline_thickness,
		"outline_color": outline_color,
		"dither_enabled": dither_enabled,
		"dither_intensity": dither_intensity,
		"dither_pattern": dither_pattern,
		"lut_enabled": lut_enabled,
		"lut_resource": lut_resource,
		"lut_intensity": lut_intensity,
		"ui_scale": ui_scale,
		"color_blind_mode": color_blind_mode,
		"high_contrast_enabled": high_contrast_enabled,
		"color_blind_shader_enabled": color_blind_shader_enabled,
	}
