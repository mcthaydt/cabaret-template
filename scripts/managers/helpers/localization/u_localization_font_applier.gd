extends RefCounted
class_name U_LocalizationFontApplier

const CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]
const FONT_THEME_TYPES: Array[StringName] = [
	&"Control", &"Label", &"Button", &"OptionButton", &"CheckBox", &"CheckButton",
	&"LineEdit", &"TextEdit", &"RichTextLabel", &"ItemList",
	&"PopupMenu", &"TabBar", &"Tree",
]

const _DEFAULT_FONT_PATH := "res://assets/fonts/fnt_ui_default.ttf"
const _DYSLEXIA_FONT_PATH := "res://assets/fonts/fnt_dyslexia.ttf"
const _CJK_FONT_PATH := "res://assets/fonts/fnt_cjk.otf"

var _default_font: Font = null
var _dyslexia_font: Font = null
var _cjk_font: Font = null

func load_fonts() -> void:
	_default_font = load(_DEFAULT_FONT_PATH) as Font
	_dyslexia_font = load(_DYSLEXIA_FONT_PATH) as Font
	_cjk_font = load(_CJK_FONT_PATH) as Font
	_apply_cjk_fallback(_default_font)
	_apply_cjk_fallback(_dyslexia_font)

func set_fonts(default_font: Font, dyslexia_font: Font, cjk_font: Font) -> void:
	_default_font = default_font
	_dyslexia_font = dyslexia_font
	_cjk_font = cjk_font
	_apply_cjk_fallback(_default_font)
	_apply_cjk_fallback(_dyslexia_font)

func get_default_font() -> Font:
	return _default_font

func get_dyslexia_font() -> Font:
	return _dyslexia_font

func get_cjk_font() -> Font:
	return _cjk_font

func get_active_font(locale: StringName, dyslexia_enabled: bool) -> Font:
	return _resolve_active_font(locale, dyslexia_enabled)

func build_theme(locale: StringName, dyslexia_enabled: bool) -> Theme:
	var active_font := _resolve_active_font(locale, dyslexia_enabled)
	if active_font == null:
		return null
	var theme := Theme.new()
	for type_name: StringName in FONT_THEME_TYPES:
		theme.set_font(&"font", type_name, active_font)
	return theme

func apply_theme_to_root(root: Node, theme: Theme) -> void:
	if root == null or theme == null:
		return
	if root is Control:
		(root as Control).theme = theme
		return
	if root is CanvasLayer:
		for child: Node in root.get_children():
			if child is Control:
				(child as Control).theme = theme

func _resolve_active_font(locale: StringName, dyslexia_enabled: bool) -> Font:
	if locale in CJK_LOCALES:
		return _cjk_font
	if dyslexia_enabled:
		return _dyslexia_font
	return _default_font

func _apply_cjk_fallback(font: Font) -> void:
	if font == null or _cjk_font == null:
		return
	if font is FontFile:
		var font_file := font as FontFile
		var fallbacks: Array = font_file.fallbacks.duplicate()
		if _cjk_font not in fallbacks:
			fallbacks.append(_cjk_font)
			font_file.fallbacks = fallbacks
