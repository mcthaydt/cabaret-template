extends RefCounted
class_name U_PaletteManager

## Helper for loading and switching UI color palettes.

signal active_palette_changed(palette)

const PALETTES := {
	"normal": preload("res://resources/ui_themes/cfg_palette_normal.tres"),
	"deuteranopia": preload("res://resources/ui_themes/cfg_palette_deuteranopia.tres"),
	"protanopia": preload("res://resources/ui_themes/cfg_palette_protanopia.tres"),
	"tritanopia": preload("res://resources/ui_themes/cfg_palette_tritanopia.tres"),
	"high_contrast": preload("res://resources/ui_themes/cfg_palette_high_contrast.tres"),
}

var _active_palette: Resource = null
var _active_key: String = ""

func set_color_blind_mode(mode: String, high_contrast_enabled: bool = false) -> void:
	var key := _resolve_palette_key(mode, high_contrast_enabled)
	var palette: Resource = PALETTES.get(key)
	if palette == null:
		key = "normal"
		palette = PALETTES.get(key)
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
	if PALETTES.has(mode):
		return mode
	return "normal"
