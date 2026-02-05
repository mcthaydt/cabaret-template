extends RefCounted
class_name U_PostProcessingPresetValues

## Loads and provides access to post-processing preset resources (light/medium/heavy).

const RS_POST_PROCESSING_PRESET := preload("res://scripts/resources/display/rs_post_processing_preset.gd")
const PRESET_DIR := "res://resources/display/cfg_post_processing_presets"

static var _presets_loaded: bool = false
static var _presets: Array = []
static var _presets_by_name: Dictionary = {}

## Get preset resource by name
static func get_preset(preset_name: String) -> Resource:
	_ensure_presets()
	if _presets_by_name.has(preset_name):
		return _presets_by_name[preset_name]
	# Default to medium if preset not found
	return _presets_by_name.get("medium", null)

## Get intensity values for a given preset as a Dictionary
static func get_preset_values(preset: String) -> Dictionary:
	var preset_resource := get_preset(preset)
	if preset_resource == null:
		return {}
	return {
		"film_grain_intensity": preset_resource.film_grain_intensity,
		"crt_scanline_intensity": preset_resource.crt_scanline_intensity,
		"crt_curvature": preset_resource.crt_curvature,
		"crt_chromatic_aberration": preset_resource.crt_chromatic_aberration,
		"dither_intensity": preset_resource.dither_intensity,
	}

## Get a specific intensity value for a preset
static func get_value(preset: String, field: String, fallback: Variant = 0.0) -> Variant:
	var preset_resource := get_preset(preset)
	if preset_resource == null:
		return fallback
	var value: Variant = preset_resource.get(field)
	if value == null:
		return fallback
	return value

## Check if a preset is valid
static func is_valid_preset(preset: String) -> bool:
	_ensure_presets()
	return _presets_by_name.has(preset)

## Get all available preset names
static func get_preset_names() -> Array[String]:
	_ensure_presets()
	var names: Array[String] = []
	for preset in _presets:
		if preset.preset_name != null and not preset.preset_name.is_empty():
			names.append(preset.preset_name)
	return names

static func _ensure_presets() -> void:
	if _presets_loaded:
		return
	_presets_loaded = true
	_presets.clear()
	_presets_by_name.clear()

	var dir := DirAccess.open(PRESET_DIR)
	if dir == null:
		push_warning("U_PostProcessingPresetValues: Cannot open preset directory '%s'" % PRESET_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var preset_path := PRESET_DIR + "/" + file_name
			var resource: Resource = load(preset_path)
			if resource != null and resource.get_script() == RS_POST_PROCESSING_PRESET:
				_presets.append(resource)
				if resource.preset_name != null and not resource.preset_name.is_empty():
					_presets_by_name[resource.preset_name] = resource
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by sort_order
	_presets.sort_custom(func(a, b): return a.sort_order < b.sort_order)
