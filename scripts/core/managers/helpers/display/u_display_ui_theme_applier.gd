extends RefCounted
class_name U_DisplayUIThemeApplier

## Applies UI theme overrides based on palette resources.

const RS_UI_COLOR_PALETTE := preload("res://scripts/core/resources/ui/rs_ui_color_palette.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/core/ui/utils/u_ui_theme_debug.gd")

var _ui_theme: Theme = null
var _ui_theme_palette_id: StringName = StringName("")
static var _active_palette: Resource = null

func apply_theme_from_palette(palette: Resource) -> void:
	if palette == null:
		_theme_debug_log("apply_theme_from_palette skipped: palette=null")
		return
	if not (palette is RS_UI_COLOR_PALETTE):
		_theme_debug_log("apply_theme_from_palette skipped: palette type mismatch")
		return
	var typed_palette := palette as RS_UI_COLOR_PALETTE
	_active_palette = typed_palette

	if U_UI_THEME_BUILDER.active_config != null:
		_theme_debug_log(
			"apply_theme_from_palette unified mode: palette_id=%s (defer application to builder)" %
			str(typed_palette.palette_id)
		)
		return

	if _ui_theme == null:
		_ui_theme = Theme.new()
	var should_update := _ui_theme_palette_id != typed_palette.palette_id
	if should_update:
		_configure_ui_theme(_ui_theme, typed_palette)
		_ui_theme_palette_id = typed_palette.palette_id
		_theme_debug_log("legacy palette theme updated: palette_id=%s" % str(typed_palette.palette_id))

func apply_theme_to_roots(roots: Array[Node]) -> void:
	if roots.is_empty():
		return
	if U_UI_THEME_BUILDER.active_config == null and _ui_theme == null:
		return
	for node in roots:
		if node == null or not is_instance_valid(node):
			continue
		apply_theme_to_node(node)

func apply_theme_to_node(node: Node) -> void:
	if U_UI_THEME_BUILDER.active_config != null:
		_theme_debug_log(
			"apply_theme_to_node unified mode: node=%s palette_id=%s" % [
				_node_name(node),
				_active_palette_id_text(),
			]
		)
		_apply_unified_theme_to_node(node)
		return
	if _ui_theme == null:
		_theme_debug_log("apply_theme_to_node skipped: legacy theme not initialized")
		return
	_theme_debug_log("apply_theme_to_node legacy mode: node=%s" % _node_name(node))
	_apply_ui_theme_to_node(node)

func get_theme() -> Theme:
	return _ui_theme

static func get_active_palette() -> Resource:
	return _active_palette

static func clear_active_palette() -> void:
	_active_palette = null

func _configure_ui_theme(theme: Theme, palette: RS_UI_COLOR_PALETTE) -> void:
	var text_color := palette.text
	var text_types: Array[String] = [
		"Label",
		"Button",
		"CheckBox",
		"OptionButton",
		"LineEdit",
		"RichTextLabel",
	]
	for type_name in text_types:
		theme.set_color("font_color", type_name, text_color)

func _apply_ui_theme_to_node(node: Node) -> void:
	if node == null or _ui_theme == null:
		return
	if node is Control:
		var control := node as Control
		if control.theme == null or control.theme == _ui_theme:
			control.theme = _ui_theme
	elif node is Window:
		_apply_theme_to_window(node as Window)
	for child in node.get_children():
		if child is Node:
			_apply_ui_theme_to_node(child)

func _apply_unified_theme_to_node(node: Node) -> void:
	if node == null:
		return
	if node is Control:
		_apply_unified_theme_to_control(node as Control)
	elif node is Window:
		_apply_unified_theme_to_window(node as Window)
	for child in node.get_children():
		if child is Node:
			_apply_unified_theme_to_node(child)

func _apply_theme_to_window(window: Window) -> void:
	if window.theme == null or window.theme == _ui_theme:
		window.theme = _ui_theme

func _apply_unified_theme_to_window(window: Window) -> void:
	var merged_theme := U_UI_THEME_BUILDER.build_theme(
		U_UI_THEME_BUILDER.active_config,
		window.theme,
		_active_palette
	)
	if merged_theme == null:
		return
	window.theme = merged_theme

func _apply_unified_theme_to_control(control: Control) -> void:
	if control == null:
		return
	var merged_theme := U_UI_THEME_BUILDER.build_theme(
		U_UI_THEME_BUILDER.active_config,
		control.theme,
		_active_palette
	)
	if merged_theme == null:
		_theme_debug_log("build_theme returned null for control=%s" % _node_name(control))
		return
	control.theme = merged_theme

func _active_palette_id_text() -> String:
	if _active_palette == null:
		return "null"
	if _active_palette is RS_UI_COLOR_PALETTE:
		return str((_active_palette as RS_UI_COLOR_PALETTE).palette_id)
	return "<invalid>"

func _node_name(node: Node) -> String:
	if node == null:
		return "<null>"
	return node.name

func _theme_debug_log(message: String) -> void:
	U_UI_THEME_DEBUG.log("U_DisplayUIThemeApplier", message)
