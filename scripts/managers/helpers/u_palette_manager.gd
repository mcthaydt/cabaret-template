extends RefCounted
class_name U_PaletteManager

## Helper for loading and switching UI color palettes.

signal active_palette_changed(palette)

const PALETTES := {
	"normal": preload("res://resources/ui_themes/cfg_palette_normal.tres"),
	"normal_high_contrast": preload("res://resources/ui_themes/cfg_palette_normal_high_contrast.tres"),
	"deuteranopia": preload("res://resources/ui_themes/cfg_palette_deuteranopia.tres"),
	"deuteranopia_high_contrast": preload("res://resources/ui_themes/cfg_palette_deuteranopia_high_contrast.tres"),
	"protanopia": preload("res://resources/ui_themes/cfg_palette_protanopia.tres"),
	"protanopia_high_contrast": preload("res://resources/ui_themes/cfg_palette_protanopia_high_contrast.tres"),
	"tritanopia": preload("res://resources/ui_themes/cfg_palette_tritanopia.tres"),
	"tritanopia_high_contrast": preload("res://resources/ui_themes/cfg_palette_tritanopia_high_contrast.tres"),
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
	var base_mode := mode if PALETTES.has(mode) else "normal"
	if high_contrast_enabled:
		var hc_key := base_mode + "_high_contrast"
		if PALETTES.has(hc_key):
			return hc_key
	return base_mode
