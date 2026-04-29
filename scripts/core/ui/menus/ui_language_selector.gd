@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_menu_screen.gd"
class_name UI_LanguageSelector

## Language Selector UI Controller (Phase 0.5B)
##
## First-run screen that lets the player choose their language.
## On subsequent launches, instantly skips to main_menu when
## has_selected_language is already true.


const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]
const I_SCENE_MANAGER := preload("res://scripts/core/interfaces/i_scene_manager.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_DEBUG_SELECTORS := preload("res://scripts/core/state/selectors/u_debug_selectors.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

@onready var _button_container: Control = %ButtonContainer
@onready var _panel_container: PanelContainer = %PanelContainer
@onready var _panel_padding: MarginContainer = %MainPanelPadding
@onready var _content_vbox: VBoxContainer = %ContentVBox
@onready var _grid_container: GridContainer = %GridContainer
@onready var _title_label: Label = %TitleLabel
@onready var _en_button: Button = %EnButton
@onready var _es_button: Button = %EsButton
@onready var _pt_button: Button = %PtButton
@onready var _zh_cn_button: Button = %ZhCnButton
@onready var _ja_button: Button = %JaButton
@onready var _background: ColorRect = $Background
var _menu_builder: RefCounted = null


func _ready() -> void:
	# Flash prevention: hide container before store lookup so the screen never
	# flashes visible on returning visits (skip path executes in same frame).
	if _button_container != null:
		_button_container.visible = false
	super._ready()


func _on_store_ready(_store_ref: M_StateStore) -> void:
	var state: Dictionary = _store_ref.get_state()
	if U_LocalizationSelectors.has_selected_language(state):
		_skip_to_main_menu()
	elif U_DEBUG_SELECTORS.should_skip_language_selection(state):
		_skip_to_main_menu()
	else:
		_setup_buttons()


func _setup_buttons() -> void:
	_setup_menu_builder()
	_apply_theme_tokens()
	if _button_container != null:
		_button_container.visible = true

	_localize_labels()

	# Build 3-column grid for keyboard/gamepad navigation:
	# Row 0: [en, es, pt]
	# Row 1: [zh_CN, ja, null]
	var grid: Array = [
		[_en_button, _es_button, _pt_button],
		[_zh_cn_button, _ja_button, null],
	]
	U_FocusConfigurator.configure_grid_focus(grid, false, false)

	if _en_button != null:
		_en_button.grab_focus()
	play_enter_animation()

func _setup_menu_builder() -> void:
	_menu_builder = U_UI_MENU_BUILDER.new(self)
	_menu_builder.bind_title(_title_label, &"menu.language_selector.title", "Select Language")
	_menu_builder.bind_button_group([
		{"button": _en_button, "key": &"locale.name.en", "callback": _on_locale_selected.bind(&"en"), "fallback": "English"},
		{"button": _es_button, "key": &"locale.name.es", "callback": _on_locale_selected.bind(&"es"), "fallback": "Español"},
		{"button": _pt_button, "key": &"locale.name.pt", "callback": _on_locale_selected.bind(&"pt"), "fallback": "Português"},
		{"button": _zh_cn_button, "key": &"locale.name.zh_cn", "callback": _on_locale_selected.bind(&"zh_CN"), "fallback": "简体中文"},
		{"button": _ja_button, "key": &"locale.name.ja", "callback": _on_locale_selected.bind(&"ja"), "fallback": "日本語"},
	])
	_menu_builder.build()

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG
	if _background != null:
		_background.color = config.bg_base
	if _panel_container != null and config.panel_section != null:
		_panel_container.add_theme_stylebox_override(&"panel", config.panel_section)
	if _panel_padding != null:
		_panel_padding.add_theme_constant_override(&"margin_left", config.margin_section)
		_panel_padding.add_theme_constant_override(&"margin_top", config.margin_section)
		_panel_padding.add_theme_constant_override(&"margin_right", config.margin_section)
		_panel_padding.add_theme_constant_override(&"margin_bottom", config.margin_section)
	if _content_vbox != null:
		_content_vbox.add_theme_constant_override(&"separation", config.separation_default)
	if _grid_container != null:
		_grid_container.add_theme_constant_override(&"h_separation", config.separation_compact)
		_grid_container.add_theme_constant_override(&"v_separation", config.separation_compact)
	if _title_label != null:
		_title_label.add_theme_font_size_override(&"font_size", config.heading)

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()

func _on_locale_selected(locale: StringName) -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_LocalizationActions.set_locale(locale))
	store.dispatch(U_LocalizationActions.mark_language_selected())
	_transition_to_main_menu()


func _skip_to_main_menu() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager == null:
		push_warning("UI_LanguageSelector: scene_manager not found — cannot skip to main_menu")
		return
	scene_manager.transition_to_scene(StringName("main_menu"), "instant")


func _transition_to_main_menu() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager == null:
		push_warning("UI_LanguageSelector: scene_manager not found — cannot transition to main_menu")
		return
	scene_manager.transition_to_scene(StringName("main_menu"), "fade")

func _get_scene_manager() -> I_SCENE_MANAGER:
	return U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SCENE_MANAGER


func _on_back_pressed() -> void:
	pass  # No back action on first-run screen

func _localize_labels() -> void:
	if _menu_builder != null:
		_menu_builder.localize_labels()
	if _en_button != null:
		_en_button.text = "%s\nEN" % U_LOCALIZATION_UTILS.localize(&"locale.name.en")
	if _es_button != null:
		_es_button.text = "%s\nES" % U_LOCALIZATION_UTILS.localize(&"locale.name.es")
	if _pt_button != null:
		_pt_button.text = "%s\nPT" % U_LOCALIZATION_UTILS.localize(&"locale.name.pt")
	if _zh_cn_button != null:
		_zh_cn_button.text = "%s\nZH_CN" % U_LOCALIZATION_UTILS.localize(&"locale.name.zh_cn")
	if _ja_button != null:
		_ja_button.text = "%s\nJA" % U_LOCALIZATION_UTILS.localize(&"locale.name.ja")
