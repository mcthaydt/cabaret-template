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
# Note: Effect order is fixed internally (Film Grain -> Dither -> CRT), not user-configurable.
@export var film_grain_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var film_grain_intensity: float = 0.1
@export var crt_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var crt_scanline_intensity: float = 0.3
@export_range(0.0, 10.0, 0.5) var crt_curvature: float = 2.0
@export_range(0.0, 0.01, 0.0001) var crt_chromatic_aberration: float = 0.002
@export var dither_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var dither_intensity: float = 0.5
@export_enum("bayer", "noise") var dither_pattern: String = "bayer"

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
		"crt_enabled": crt_enabled,
		"crt_scanline_intensity": crt_scanline_intensity,
		"crt_curvature": crt_curvature,
		"crt_chromatic_aberration": crt_chromatic_aberration,
		"dither_enabled": dither_enabled,
		"dither_intensity": dither_intensity,
		"dither_pattern": dither_pattern,
		"ui_scale": ui_scale,
		"color_blind_mode": color_blind_mode,
		"high_contrast_enabled": high_contrast_enabled,
		"color_blind_shader_enabled": color_blind_shader_enabled,
	}
