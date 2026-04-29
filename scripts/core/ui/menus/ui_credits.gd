@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_menu_screen.gd"
class_name UI_Credits

## Credits screen controller (Phase 9)
##
## Auto-scrolls credits content and returns to main menu after a timeout.
## Skip button allows players to exit immediately.


const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _skip_button: Button = %SkipButton
@onready var _content_vbox: VBoxContainer = %ContentVBox
@onready var _header_label: Label = %HeaderLabel
@onready var _team_label: Label = %TeamLabel
@onready var _names_label: Label = %NamesLabel
@onready var _thanks_label: Label = %ThanksLabel
@onready var _footer_label: Label = %FooterLabel
@onready var _background: ColorRect = $Background
@onready var _content_margin: MarginContainer = $MarginContainer
@onready var _panel_padding: MarginContainer = $MarginContainer/CenterContainer/MainPanel/MainPanelPadding
@onready var _skip_button_margin: MarginContainer = $SkipButtonMargin

var _scroll_tween: Tween = null
var _auto_return_timer: Timer = null
var _scroll_duration: float = 55.0
var _auto_return_duration: float = 60.0
var _is_returning: bool = false
var _menu_builder: RefCounted = null

func set_test_durations(scroll_duration: float, auto_return_duration: float) -> void:
	_scroll_duration = max(scroll_duration, 0.01)
	_auto_return_duration = max(auto_return_duration, 0.01)

	if _auto_return_timer != null:
		_auto_return_timer.stop()
		_auto_return_timer.wait_time = _auto_return_duration
		_auto_return_timer.start()

	_restart_scroll_tween()

func _on_panel_ready() -> void:
	_setup_menu_builder()
	_apply_theme_tokens()
	_localize_labels()
	_start_auto_return_timer()
	_start_scroll_tween()
	play_enter_animation()

func _setup_menu_builder() -> void:
	_menu_builder = U_UI_MENU_BUILDER.new(self)
	_menu_builder.bind_button(_skip_button, &"common.skip", _on_skip_pressed)
	_menu_builder.build()

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG
	if _background != null:
		_background.color = config.bg_base
	if _content_margin != null:
		_content_margin.add_theme_constant_override(&"margin_left", config.margin_outer)
		_content_margin.add_theme_constant_override(&"margin_top", config.margin_outer)
		_content_margin.add_theme_constant_override(&"margin_right", config.margin_outer)
		_content_margin.add_theme_constant_override(&"margin_bottom", config.margin_outer)
	if _panel_padding != null:
		_panel_padding.add_theme_constant_override(&"margin_left", config.margin_inner)
		_panel_padding.add_theme_constant_override(&"margin_top", config.margin_inner)
		_panel_padding.add_theme_constant_override(&"margin_right", config.margin_inner)
		_panel_padding.add_theme_constant_override(&"margin_bottom", config.margin_inner)
	if _skip_button_margin != null:
		_skip_button_margin.add_theme_constant_override(&"margin_left", config.margin_outer)
		_skip_button_margin.add_theme_constant_override(&"margin_top", config.margin_outer)
		_skip_button_margin.add_theme_constant_override(&"margin_right", config.margin_outer)
		_skip_button_margin.add_theme_constant_override(&"margin_bottom", config.margin_outer)
	if _content_vbox != null:
		_content_vbox.add_theme_constant_override(&"separation", config.separation_medium)
	if _header_label != null:
		_header_label.add_theme_font_size_override(&"font_size", config.title)
	if _team_label != null:
		_team_label.add_theme_font_size_override(&"font_size", config.heading)
		_team_label.add_theme_color_override(&"font_color", config.text_secondary)
	if _names_label != null:
		_names_label.add_theme_font_size_override(&"font_size", config.body)
	if _thanks_label != null:
		_thanks_label.add_theme_font_size_override(&"font_size", config.body)
	if _footer_label != null:
		_footer_label.add_theme_font_size_override(&"font_size", config.caption)
		_footer_label.add_theme_color_override(&"font_color", config.text_secondary)

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()

func _localize_labels() -> void:
	if _menu_builder != null:
		_menu_builder.localize_labels()
	if _team_label != null:
		_team_label.text = U_LOCALIZATION_UTILS.localize(&"menu.credits.team")
	if _names_label != null:
		_names_label.text = U_LOCALIZATION_UTILS.localize(&"menu.credits.roles")
	if _thanks_label != null:
		_thanks_label.text = U_LOCALIZATION_UTILS.localize(&"menu.credits.thanks")
	if _footer_label != null:
		_footer_label.text = U_LOCALIZATION_UTILS.localize(&"menu.credits.copyright")

func _exit_tree() -> void:
	if _auto_return_timer != null:
		_auto_return_timer.stop()
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()
	_scroll_tween = null
	_auto_return_timer = null

func _start_auto_return_timer() -> void:
	if _auto_return_timer == null:
		_auto_return_timer = Timer.new()
		_auto_return_timer.one_shot = true
		add_child(_auto_return_timer)
		_auto_return_timer.timeout.connect(_on_auto_return_timeout)

	_auto_return_timer.wait_time = _auto_return_duration
	_auto_return_timer.start()

func _start_scroll_tween() -> void:
	if _scroll_container == null:
		return

	var vbar := _scroll_container.get_v_scroll_bar()
	if vbar == null:
		return

	_scroll_container.scroll_vertical = 0

	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()

	_scroll_tween = create_tween()
	_scroll_tween.tween_property(
		_scroll_container,
		"scroll_vertical",
		vbar.max_value,
		_scroll_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func _restart_scroll_tween() -> void:
	if not is_inside_tree():
		return
	_start_scroll_tween()

func _on_skip_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_return_to_main_menu()

func _on_auto_return_timeout() -> void:
	_return_to_main_menu()

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	if _is_returning:
		return
	_is_returning = true

	if _auto_return_timer != null:
		_auto_return_timer.stop()
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()

	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.skip_to_menu())
