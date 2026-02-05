extends RefCounted
class_name U_PostProcessingPresetValues

## Defines intensity values for each post-processing preset (light/medium/heavy).

const PRESET_VALUES := {
	"light": {
		"film_grain_intensity": 0.05,
		"crt_scanline_intensity": 0.15,
		"crt_curvature": 1.0,
		"crt_chromatic_aberration": 0.001,
		"dither_intensity": 0.25,
	},
	"medium": {
		"film_grain_intensity": 0.1,
		"crt_scanline_intensity": 0.3,
		"crt_curvature": 2.0,
		"crt_chromatic_aberration": 0.002,
		"dither_intensity": 0.5,
	},
	"heavy": {
		"film_grain_intensity": 0.2,
		"crt_scanline_intensity": 0.5,
		"crt_curvature": 4.0,
		"crt_chromatic_aberration": 0.004,
		"dither_intensity": 0.75,
	},
}

## Get intensity values for a given preset
static func get_preset_values(preset: String) -> Dictionary:
	if PRESET_VALUES.has(preset):
		return PRESET_VALUES[preset].duplicate(true)
	# Default to medium if preset not found
	return PRESET_VALUES["medium"].duplicate(true)

## Get a specific intensity value for a preset
static func get_value(preset: String, field: String, fallback: Variant = 0.0) -> Variant:
	var values := get_preset_values(preset)
	return values.get(field, fallback)

## Check if a preset is valid
static func is_valid_preset(preset: String) -> bool:
	return PRESET_VALUES.has(preset)

## Get all available preset names
static func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for key in PRESET_VALUES.keys():
		names.append(key)
	return names
