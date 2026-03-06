extends RefCounted
class_name U_LocalizationFontApplier

const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const U_DISPLAY_UI_THEME_APPLIER := preload("res://scripts/managers/helpers/display/u_display_ui_theme_applier.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/ui/utils/u_ui_theme_debug.gd")

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
		_theme_debug_log(
			"build_theme active_font=null locale=%s dyslexia=%s (returning null)" % [
				str(locale),
				str(dyslexia_enabled),
			]
		)
		return null
	var theme := Theme.new()
	for type_name: StringName in FONT_THEME_TYPES:
		theme.set_font(&"font", type_name, active_font)
	return _compose_theme(theme)

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

func _compose_theme(font_theme: Theme) -> Theme:
	if font_theme == null:
		return null
	if U_UI_THEME_BUILDER.active_config == null:
		_theme_debug_log("compose_theme active_config=null (font-only theme)")
		return font_theme
	var active_palette: Resource = U_DISPLAY_UI_THEME_APPLIER.get_active_palette()
	_theme_debug_log(
		"compose_theme unified active_config=true palette=%s" % [
			str(active_palette != null),
		]
	)
	var merged_theme := U_UI_THEME_BUILDER.build_theme(
		U_UI_THEME_BUILDER.active_config,
		font_theme,
		active_palette
	)
	if merged_theme == null:
		_theme_debug_log("compose_theme merged_theme=null (falling back to font-only)")
		return font_theme
	return merged_theme

func _theme_debug_log(message: String) -> void:
	U_UI_THEME_DEBUG.log("U_LocalizationFontApplier", message)
