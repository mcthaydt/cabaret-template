@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_DisplayInitialState

## Display Initial State Resource (Phase 0 - Task 0A.2)
##
## Defines default display settings for the display slice.

const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

@export_group("Graphics")
@export var window_size_preset: String = "1920x1080"
@export_enum("windowed", "fullscreen", "borderless") var window_mode: String = "windowed"
@export var vsync_enabled: bool = true
@export_enum("low", "medium", "high", "ultra") var quality_preset: String = "high"

@export_group("Post-Processing")
@export var post_processing_enabled: bool = false
@export_enum("light", "medium", "heavy") var post_processing_preset: String = "medium"
@export var film_grain_enabled: bool = false
@export var dither_enabled: bool = false
@export_enum("bayer", "noise") var dither_pattern: String = "bayer"
@export var scanlines_enabled: bool = false
# Note: Effect order is fixed internally (Film Grain -> Dither), not user-configurable.
# Note: Intensity values are loaded from post_processing_preset resource.

@export_group("UI")
@export_range(0.8, 1.3, 0.1) var ui_scale: float = 1.0

@export_group("Accessibility")
@export_enum("normal", "deuteranopia", "protanopia", "tritanopia") var color_blind_mode: String = "normal"
@export var high_contrast_enabled: bool = false
@export var color_blind_shader_enabled: bool = false

@export_group("Mobile")
@export_range(0.25, 1.0, 0.05) var mobile_resolution_scale: float = 0.35

## Convert resource to Dictionary for state store.
## On mobile, overrides graphics defaults for better performance.
func to_dictionary() -> Dictionary:
	# Load intensity values from preset
	var preset_values := U_PostProcessingPresetValues.get_preset_values(post_processing_preset)

	var result := {
		"window_size_preset": window_size_preset,
		"window_mode": window_mode,
		"vsync_enabled": vsync_enabled,
		"quality_preset": quality_preset,
		"post_processing_enabled": post_processing_enabled,
		"post_processing_preset": post_processing_preset,
		"film_grain_enabled": film_grain_enabled,
		"dither_enabled": dither_enabled,
		"dither_pattern": dither_pattern,
		"film_grain_intensity": preset_values.get("film_grain_intensity", 0.2),
		"dither_intensity": preset_values.get("dither_intensity", 1.0),
		"scanlines_enabled": scanlines_enabled,
		"scanline_intensity": preset_values.get("scanline_intensity", 0.0),
		"scanline_count": preset_values.get("scanline_count", 480.0),
		"ui_scale": ui_scale,
		"color_blind_mode": color_blind_mode,
		"high_contrast_enabled": high_contrast_enabled,
		"color_blind_shader_enabled": color_blind_shader_enabled,
		"mobile_resolution_scale": mobile_resolution_scale,
	}

	# Mobile override: downgrade defaults for better performance
	if U_MOBILE_PLATFORM_DETECTOR.is_mobile():
		result["quality_preset"] = "low"
		result["post_processing_enabled"] = false
		result["film_grain_enabled"] = false
		result["dither_enabled"] = false
		result["scanlines_enabled"] = false

	return result
