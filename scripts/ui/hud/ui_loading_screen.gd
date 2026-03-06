@icon("res://assets/editor_icons/icn_utility.svg")
extends Control
class_name UI_LoadingScreen

const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/resources/ui/rs_ui_theme_config.gd")
const U_TWEEN_MANAGER := preload("res://scripts/scene_management/u_tween_manager.gd")

@export var background_path: NodePath = NodePath("ColorRect")
@export var content_path: NodePath = NodePath("CenterContainer/VBoxContainer")
@export var logo_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/LogoLabel")
@export var spinner_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/SpinnerLabel")
@export var status_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/StatusLabel")
@export var tip_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/TipLabel")
@export var fade_in_duration_sec: float = 0.18

var _background: ColorRect = null
var _content: VBoxContainer = null
var _logo_label: Label = null
var _spinner_label: Label = null
var _status_label: Label = null
var _tip_label: Label = null
var _fade_tween: Tween = null

func _ready() -> void:
	_cache_nodes()
	_apply_theme_tokens()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _exit_tree() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

func _cache_nodes() -> void:
	_background = get_node_or_null(background_path) as ColorRect
	_content = get_node_or_null(content_path) as VBoxContainer
	_logo_label = get_node_or_null(logo_label_path) as Label
	_spinner_label = get_node_or_null(spinner_label_path) as Label
	_status_label = get_node_or_null(status_label_path) as Label
	_tip_label = get_node_or_null(tip_label_path) as Label

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG

	if _background != null:
		_background.color = config.bg_base
	if _content != null:
		_content.add_theme_constant_override(&"separation", config.margin_outer)
	if _logo_label != null:
		_logo_label.add_theme_font_size_override(&"font_size", config.title)
	if _spinner_label != null:
		_spinner_label.add_theme_font_size_override(&"font_size", config.heading)
	if _status_label != null:
		_status_label.add_theme_font_size_override(&"font_size", config.body_small)
	if _tip_label != null:
		_tip_label.add_theme_font_size_override(&"font_size", config.section_header)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = null
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	if fade_in_duration_sec <= 0.0:
		modulate.a = 1.0
		return
	_fade_tween = U_TWEEN_MANAGER.create_transition_tween(self)
	if _fade_tween == null:
		modulate.a = 1.0
		return
	_fade_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration_sec).from(0.0)
	_fade_tween.finished.connect(_on_fade_finished)

func _on_fade_finished() -> void:
	_fade_tween = null
