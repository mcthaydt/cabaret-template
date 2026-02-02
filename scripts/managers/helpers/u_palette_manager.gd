extends RefCounted
class_name U_PaletteManager

## Helper for loading and switching UI color palettes.

signal active_palette_changed(palette)

const RS_UI_COLOR_PALETTE := preload("res://scripts/resources/ui/rs_ui_color_palette.gd")

const PALETTE_PATHS := {
	"normal": "res://resources/ui_themes/cfg_palette_normal.tres",
	"deuteranopia": "res://resources/ui_themes/cfg_palette_deuteranopia.tres",
	"protanopia": "res://resources/ui_themes/cfg_palette_protanopia.tres",
	"tritanopia": "res://resources/ui_themes/cfg_palette_tritanopia.tres",
	"high_contrast": "res://resources/ui_themes/cfg_palette_high_contrast.tres",
}

var _palette_cache: Dictionary = {}
var _active_palette: Resource = null
var _active_key: String = ""

func set_color_blind_mode(mode: String, high_contrast_enabled: bool = false) -> void:
	var key := _resolve_palette_key(mode, high_contrast_enabled)
	var palette := _load_palette(key)
	if palette == null:
		key = "normal"
		palette = _load_palette(key)
	if palette == null:
		return
	if _active_palette == palette and _active_key == key:
		return
	_active_palette = palette
	_active_key = key
	emit_signal("active_palette_changed", palette)

func get_active_palette() -> Resource:
	return _active_palette

func _resolve_palette_key(mode: String, high_contrast_enabled: bool) -> String:
	if high_contrast_enabled:
		return "high_contrast"
	if PALETTE_PATHS.has(mode):
		return mode
	return "normal"

func _load_palette(key: String) -> Resource:
	if _palette_cache.has(key):
		var cached: Variant = _palette_cache[key]
		if cached is Resource and (cached as Resource).get_script() == RS_UI_COLOR_PALETTE:
			return cached as Resource

	var path: String = String(PALETTE_PATHS.get(key, ""))
	if path.is_empty():
		return null
	var resource: Resource = load(path)
	if resource == null or resource.get_script() != RS_UI_COLOR_PALETTE:
		push_warning("U_PaletteManager: Failed to load palette '%s' (%s)" % [key, path])
		return null
	_palette_cache[key] = resource
	return resource
