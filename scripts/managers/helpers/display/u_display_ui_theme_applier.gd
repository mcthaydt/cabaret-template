extends RefCounted

## Applies UI theme overrides based on palette resources.

const RS_UI_COLOR_PALETTE := preload("res://scripts/resources/ui/rs_ui_color_palette.gd")

var _ui_theme: Theme = null
var _ui_theme_palette_id: StringName = StringName("")

func apply_theme_from_palette(palette: Resource) -> void:
	if palette == null:
		return
	if not (palette is RS_UI_COLOR_PALETTE):
		return
	var typed_palette := palette as RS_UI_COLOR_PALETTE
	if _ui_theme == null:
		_ui_theme = Theme.new()
	var should_update := _ui_theme_palette_id != typed_palette.palette_id
	if should_update:
		_configure_ui_theme(_ui_theme, typed_palette)
		_ui_theme_palette_id = typed_palette.palette_id

func apply_theme_to_roots(roots: Array[Node]) -> void:
	if _ui_theme == null:
		return
	if roots.is_empty():
		return
	for node in roots:
		if node == null or not is_instance_valid(node):
			continue
		_apply_ui_theme_to_node(node)

func apply_theme_to_node(node: Node) -> void:
	if _ui_theme == null:
		return
	_apply_ui_theme_to_node(node)

func get_theme() -> Theme:
	return _ui_theme

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
	var children: Array = node.get_children()
	for child in children:
		if child is Node:
			_apply_ui_theme_to_node(child)
