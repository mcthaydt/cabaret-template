extends RefCounted
class_name U_DisplayOptionCatalog

## Display option catalog for data-driven UI + manager presets.

const RS_QUALITY_PRESET := preload("res://scripts/resources/display/rs_quality_preset.gd")
const RS_WINDOW_SIZE_PRESET := preload("res://scripts/resources/display/rs_window_size_preset.gd")

const QUALITY_PRESET_DIR := "res://resources/display/cfg_quality_presets"
const WINDOW_SIZE_PRESET_DIR := "res://resources/display/cfg_window_size_presets"

# Preloaded quality presets (mobile-compatible - avoids runtime DirAccess on Android)
const QUALITY_PRESETS := [
	preload("res://resources/display/cfg_quality_presets/cfg_quality_low.tres"),
	preload("res://resources/display/cfg_quality_presets/cfg_quality_medium.tres"),
	preload("res://resources/display/cfg_quality_presets/cfg_quality_high.tres"),
	preload("res://resources/display/cfg_quality_presets/cfg_quality_ultra.tres"),
]

# Preloaded window size presets (mobile-compatible - avoids runtime DirAccess on Android)
const WINDOW_SIZE_PRESETS := [
	preload("res://resources/display/cfg_window_size_presets/cfg_window_size_1280x720.tres"),
	preload("res://resources/display/cfg_window_size_presets/cfg_window_size_1600x900.tres"),
	preload("res://resources/display/cfg_window_size_presets/cfg_window_size_1920x1080.tres"),
	preload("res://resources/display/cfg_window_size_presets/cfg_window_size_2560x1440.tres"),
	preload("res://resources/display/cfg_window_size_presets/cfg_window_size_3840x2160.tres"),
]

const WINDOW_MODE_OPTIONS := [
	{"id": "windowed", "label": "Windowed"},
	{"id": "fullscreen", "label": "Fullscreen"},
	{"id": "borderless", "label": "Borderless"},
]

const DITHER_PATTERN_OPTIONS := [
	{"id": "bayer", "label": "Bayer"},
	{"id": "noise", "label": "Noise"},
]

const COLOR_BLIND_MODE_OPTIONS := [
	{"id": "normal", "label": "Normal"},
	{"id": "deuteranopia", "label": "Deuteranopia"},
	{"id": "protanopia", "label": "Protanopia"},
	{"id": "tritanopia", "label": "Tritanopia"},
]

const POST_PROCESSING_PRESET_OPTIONS := [
	{"id": "light", "label": "Light"},
	{"id": "medium", "label": "Medium"},
	{"id": "heavy", "label": "Heavy"},
]

static var _quality_presets_loaded: bool = false
static var _quality_presets: Array = []
static var _quality_presets_by_id: Dictionary = {}

static var _window_size_presets_loaded: bool = false
static var _window_size_presets: Array = []
static var _window_size_presets_by_id: Dictionary = {}

static func get_quality_presets() -> Array:
	_ensure_quality_presets()
	return _quality_presets.duplicate()

static func get_quality_preset_by_id(preset_id: String) -> Resource:
	_ensure_quality_presets()
	if _quality_presets_by_id.has(preset_id):
		return _quality_presets_by_id[preset_id]
	return null

static func get_quality_option_entries() -> Array[Dictionary]:
	_ensure_quality_presets()
	var entries: Array[Dictionary] = []
	for preset in _quality_presets:
		var preset_name: String = String(preset.get("preset_name"))
		var label: String = String(preset.get("display_name"))
		if label.is_empty():
			label = preset_name.capitalize()
		entries.append({
			"id": preset_name,
			"label": label
		})
	return entries

static func get_window_size_presets() -> Array:
	_ensure_window_size_presets()
	return _window_size_presets.duplicate()

static func get_window_mode_option_entries() -> Array[Dictionary]:
	return _duplicate_option_entries(WINDOW_MODE_OPTIONS)

static func get_dither_pattern_option_entries() -> Array[Dictionary]:
	return _duplicate_option_entries(DITHER_PATTERN_OPTIONS)

static func get_color_blind_mode_option_entries() -> Array[Dictionary]:
	return _duplicate_option_entries(COLOR_BLIND_MODE_OPTIONS)

static func get_post_processing_preset_option_entries() -> Array[Dictionary]:
	return _duplicate_option_entries(POST_PROCESSING_PRESET_OPTIONS)

static func get_window_size_preset_by_id(preset_id: String) -> Resource:
	_ensure_window_size_presets()
	if _window_size_presets_by_id.has(preset_id):
		return _window_size_presets_by_id[preset_id]
	return null

static func get_window_size_option_entries() -> Array[Dictionary]:
	_ensure_window_size_presets()
	var entries: Array[Dictionary] = []
	for preset in _window_size_presets:
		var preset_id: String = String(preset.get("preset_id"))
		var label: String = String(preset.get("label"))
		var size: Vector2i = Vector2i(0, 0)
		var size_value: Variant = preset.get("size")
		if size_value is Vector2i:
			size = size_value
		if label.is_empty():
			if not preset_id.is_empty():
				label = preset_id
			else:
				label = "%dx%d" % [size.x, size.y]
		entries.append({
			"id": preset_id,
			"label": label
		})
	return entries

static func get_window_size_ids() -> Array[String]:
	_ensure_window_size_presets()
	var ids: Array[String] = []
	for preset in _window_size_presets:
		ids.append(String(preset.get("preset_id")))
	return ids

static func get_quality_ids() -> Array[String]:
	_ensure_quality_presets()
	var ids: Array[String] = []
	for preset in _quality_presets:
		ids.append(String(preset.get("preset_name")))
	return ids

static func get_window_mode_ids() -> Array[String]:
	return _extract_option_ids(WINDOW_MODE_OPTIONS)

static func get_dither_pattern_ids() -> Array[String]:
	return _extract_option_ids(DITHER_PATTERN_OPTIONS)

static func get_color_blind_mode_ids() -> Array[String]:
	return _extract_option_ids(COLOR_BLIND_MODE_OPTIONS)

static func get_post_processing_preset_ids() -> Array[String]:
	return _extract_option_ids(POST_PROCESSING_PRESET_OPTIONS)

static func _ensure_quality_presets() -> void:
	if _quality_presets_loaded:
		return
	_quality_presets_loaded = true
	_quality_presets.clear()
	_quality_presets_by_id.clear()

	# Use preloaded resources for mobile compatibility
	for preset in QUALITY_PRESETS:
		if _is_quality_preset(preset):
			var preset_name: String = String(preset.get("preset_name"))
			if preset_name.is_empty():
				continue
			_quality_presets.append(preset)
			_quality_presets_by_id[preset_name] = preset

	_quality_presets.sort_custom(func(a, b):
		return int(a.get("sort_order")) < int(b.get("sort_order"))
	)

static func _ensure_window_size_presets() -> void:
	if _window_size_presets_loaded:
		return
	_window_size_presets_loaded = true
	_window_size_presets.clear()
	_window_size_presets_by_id.clear()

	# Use preloaded resources for mobile compatibility
	for preset in WINDOW_SIZE_PRESETS:
		if _is_window_size_preset(preset):
			var preset_id: String = String(preset.get("preset_id"))
			if preset_id.is_empty():
				continue
			_window_size_presets.append(preset)
			_window_size_presets_by_id[preset_id] = preset

	_window_size_presets.sort_custom(func(a, b):
		return int(a.get("sort_order")) < int(b.get("sort_order"))
	)

static func _is_quality_preset(resource: Resource) -> bool:
	return resource != null and resource.get_script() == RS_QUALITY_PRESET

static func _is_window_size_preset(resource: Resource) -> bool:
	return resource != null and resource.get_script() == RS_WINDOW_SIZE_PRESET

static func _load_preset_resources(dir_path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				results.append_array(_load_preset_resources("%s/%s" % [dir_path, entry]))
		elif entry.ends_with(".tres"):
			var path := "%s/%s" % [dir_path, entry]
			var resource := load(path)
			if resource != null:
				results.append(resource)
		entry = dir.get_next()
	dir.list_dir_end()
	return results

static func _duplicate_option_entries(options: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for option in options:
		if option is Dictionary:
			entries.append((option as Dictionary).duplicate(true))
	return entries

static func _extract_option_ids(options: Array) -> Array[String]:
	var ids: Array[String] = []
	for option in options:
		if option is Dictionary:
			ids.append(String(option.get("id", "")))
	return ids
