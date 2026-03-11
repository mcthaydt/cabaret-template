@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_UIThemeConfig

## Global UI theme configuration for visual styling and spacing.

@export_group("Typography")
@export var title: int = 48
@export var heading: int = 32
@export var subheading: int = 24
@export var body: int = 22
@export var body_small: int = 18
@export var caption: int = 16
@export var section_header: int = 14
@export var caption_small: int = 12

@export_group("Colors")
@export var bg_base: Color = Color(0.114, 0.114, 0.129, 1.0)
@export var bg_panel: Color = Color(0.157, 0.169, 0.290, 1.0)
@export var bg_panel_light: Color = Color(0.231, 0.220, 0.333, 1.0)
@export var bg_surface: Color = Color(0.263, 0.271, 0.286, 1.0)
@export var text_primary: Color = Color(0.961, 0.969, 0.980, 1.0)
@export var text_secondary: Color = Color(0.804, 0.824, 0.855, 1.0)
@export var text_disabled: Color = Color(0.510, 0.545, 0.596, 1.0)
@export var accent_primary: Color = Color(0.255, 0.698, 0.890, 1.0)
@export var accent_hover: Color = Color(0.322, 0.824, 1.0, 1.0)
@export var accent_pressed: Color = Color(0.193, 0.557, 0.722, 1.0)
@export var accent_focus: Color = Color(0.333, 0.694, 0.945, 1.0)
@export var section_header_color: Color = Color(0.588, 0.698, 0.851, 1.0)
@export var danger: Color = Color(0.894, 0.361, 0.373, 1.0)
@export var success: Color = Color(0.490, 0.643, 0.176, 1.0)
@export var warning: Color = Color(1.0, 0.737, 0.306, 1.0)
@export var golden: Color = Color(0.925, 0.773, 0.506, 1.0)
@export var health_bg: Color = Color(0.227, 0.271, 0.408, 1.0)
@export var slider_fill_color: Color = Color(0.255, 0.698, 0.890, 1.0)
@export var slider_bg_color: Color = Color(0.263, 0.271, 0.286, 1.0)

@export_group("Spacing")
@export var margin_outer: int = 20
@export var margin_section: int = 16
@export var margin_inner: int = 12
@export var separation_large: int = 32
@export var separation_medium: int = 24
@export var separation_default: int = 12
@export var separation_compact: int = 8

@export_group("Button Styles")
@export var button_normal: StyleBoxFlat
@export var button_hover: StyleBoxFlat
@export var button_pressed: StyleBoxFlat
@export var button_focus: StyleBoxFlat
@export var button_disabled: StyleBoxFlat

@export_group("Panel Styles")
@export_range(0.0, 1.0, 0.01) var panel_section_opacity: float = 0.78
@export var panel_section: StyleBoxFlat
@export var panel_signpost: StyleBoxFlat
@export var panel_button_prompt: StyleBoxFlat

@export_group("Bar Styles")
@export var progress_bar_bg: StyleBoxFlat
@export var progress_bar_fill: StyleBoxFlat
@export var slider_bg: StyleBoxFlat
@export var slider_fill: StyleBoxFlat
@export var slider_grabber: StyleBoxFlat
@export var slider_grabber_highlight: StyleBoxFlat

@export_group("Focus")
@export var focus_stylebox: StyleBoxFlat

@export_group("Separator")
@export var separator_style: StyleBoxFlat

func _init() -> void:
	ensure_runtime_defaults()

func ensure_runtime_defaults() -> void:
	if button_normal == null:
		button_normal = _create_box(bg_panel, accent_primary, 2, 10)
	if button_hover == null:
		button_hover = _create_box(bg_panel_light, accent_hover, 2, 10)
	if button_pressed == null:
		button_pressed = _create_box(accent_pressed, accent_pressed, 2, 10)
	if button_focus == null:
		button_focus = _create_box(bg_panel_light, accent_focus, 3, 10)
	if button_disabled == null:
		button_disabled = _create_box(bg_surface, text_disabled, 1, 10)

	if panel_section == null:
		var panel_section_bg := bg_panel
		panel_section_bg.a = clampf(panel_section_bg.a * panel_section_opacity, 0.0, 1.0)
		panel_section = _create_box(panel_section_bg, bg_panel_light, 1, 12)
		panel_section.set_expand_margin_all(1)
	if panel_signpost == null:
		panel_signpost = _create_box(bg_panel, golden, 1, 12)
	if panel_button_prompt == null:
		panel_button_prompt = _create_box(bg_panel, accent_primary, 1, 8)

	if progress_bar_bg == null:
		progress_bar_bg = _create_box(health_bg, bg_panel_light, 1, 8)
	if progress_bar_fill == null:
		progress_bar_fill = _create_box(success, success, 1, 8)
	if slider_bg == null:
		slider_bg = _create_box(slider_bg_color, bg_panel_light, 1, 6)
	if slider_fill == null:
		slider_fill = _create_box(slider_fill_color, slider_fill_color, 1, 6)
	if slider_grabber == null:
		slider_grabber = _create_box(accent_primary, accent_hover, 1, 6)
		slider_grabber.content_margin_left = 6.0
		slider_grabber.content_margin_right = 6.0
		slider_grabber.content_margin_top = 6.0
		slider_grabber.content_margin_bottom = 6.0
	if slider_grabber_highlight == null:
		slider_grabber_highlight = _create_box(accent_hover, accent_hover, 1, 6)
		slider_grabber_highlight.content_margin_left = 6.0
		slider_grabber_highlight.content_margin_right = 6.0
		slider_grabber_highlight.content_margin_top = 6.0
		slider_grabber_highlight.content_margin_bottom = 6.0

	if focus_stylebox == null:
		focus_stylebox = _create_box(Color(0.0, 0.0, 0.0, 0.0), accent_focus, 2, 10)
		focus_stylebox.set_expand_margin_all(2)

	if separator_style == null:
		separator_style = _create_box(bg_panel_light, bg_panel_light, 0, 0)
		separator_style.content_margin_top = 1.0
		separator_style.content_margin_bottom = 1.0

func _create_box(bg_color: Color, border_color: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
