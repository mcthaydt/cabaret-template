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
@export var post_processing_enabled: bool = false
@export_enum("light", "medium", "heavy") var post_processing_preset: String = "medium"
@export var film_grain_enabled: bool = false
@export var crt_enabled: bool = false
@export var dither_enabled: bool = false
# Note: Effect order is fixed internally (Film Grain -> Dither -> CRT), not user-configurable.
# Note: Intensity values are loaded from post_processing_preset resource.

@export_group("UI")
@export_range(0.8, 1.3, 0.1) var ui_scale: float = 1.0

@export_group("Accessibility")
@export_enum("normal", "deuteranopia", "protanopia", "tritanopia") var color_blind_mode: String = "normal"
@export var high_contrast_enabled: bool = false

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	# Load intensity values from preset
	const U_PostProcessingPresetValues := preload("res://scripts/utils/display/u_post_processing_preset_values.gd")
	var preset_values := U_PostProcessingPresetValues.get_preset_values(post_processing_preset)

	return {
		"window_size_preset": window_size_preset,
		"window_mode": window_mode,
		"vsync_enabled": vsync_enabled,
		"quality_preset": quality_preset,
		"post_processing_enabled": post_processing_enabled,
		"post_processing_preset": post_processing_preset,
		"film_grain_enabled": film_grain_enabled,
		"crt_enabled": crt_enabled,
		"dither_enabled": dither_enabled,
		"film_grain_intensity": preset_values.get("film_grain_intensity", 0.2),
		"crt_scanline_intensity": preset_values.get("crt_scanline_intensity", 0.25),
		"crt_curvature": preset_values.get("crt_curvature", 0.0),
		"crt_chromatic_aberration": preset_values.get("crt_chromatic_aberration", 0.001),
		"dither_intensity": preset_values.get("dither_intensity", 1.0),
		"ui_scale": ui_scale,
		"color_blind_mode": color_blind_mode,
		"high_contrast_enabled": high_contrast_enabled,
	}
