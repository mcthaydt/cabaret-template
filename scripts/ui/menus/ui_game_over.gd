@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_menu_screen.gd"
class_name UI_GameOver

## Game Over screen controller (Phase 9)
##
## Shows total death count and dispatches navigation actions:
## - Retry: Soft reset player state and return to last gameplay scene.
## - Menu: Soft reset and return to main menu.


const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")
const U_TRANSITION_OVERLAY_SNAP := preload("res://scripts/scene_management/helpers/u_transition_overlay_snap.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/resources/ui/rs_ui_theme_config.gd")
const RS_UI_MOTION_PRESET := preload("res://scripts/resources/ui/rs_ui_motion_preset.gd")

@onready var _title_label: Label = %TitleLabel
@onready var _death_count_label: Label = %DeathCountLabel
@onready var _button_row: HBoxContainer = $MarginContainer/CenterContainer/MainPanel/MainPanelPadding/VBoxContainer/ButtonRow
@onready var _content_vbox: VBoxContainer = $MarginContainer/CenterContainer/MainPanel/MainPanelPadding/VBoxContainer
@onready var _background: ColorRect = $Background
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MenuButton

var _store_unsubscribe: Callable = Callable()

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_update_death_count(store.get_state())

func _on_panel_ready() -> void:
	_apply_theme_tokens()
	_connect_buttons()
	_configure_focus_neighbors()
	_localize_labels()
	play_enter_animation()
	_play_title_enter_motion()

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG
	if _background != null:
		_background.color = config.bg_base
	if _content_vbox != null:
		_content_vbox.add_theme_constant_override(&"separation", config.separation_large)
	if _button_row != null:
		_button_row.add_theme_constant_override(&"separation", config.separation_medium)
	if _title_label != null:
		_title_label.add_theme_font_size_override(&"font_size", config.title)
		_title_label.add_theme_color_override(&"font_color", config.danger)
	if _death_count_label != null:
		_death_count_label.add_theme_font_size_override(&"font_size", config.heading)
		_death_count_label.add_theme_color_override(&"font_color", config.text_secondary)

func _play_title_enter_motion() -> void:
	if _title_label == null:
		return
	var preset: Resource = RS_UI_MOTION_PRESET.new()
	preset.property_path = "modulate:a"
	preset.from_value = 0.0
	preset.to_value = 1.0
	preset.duration_sec = 0.24
	preset.delay_sec = 0.1
	var presets: Array[Resource] = [preset]
	U_UI_MOTION.play(_title_label, presets)

func _configure_focus_neighbors() -> void:
	# Configure horizontal focus navigation for game over buttons with wrapping
	var buttons: Array[Control] = []
	if _retry_button != null:
		buttons.append(_retry_button)
	if _menu_button != null:
		buttons.append(_menu_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()

func _connect_buttons() -> void:
	if _retry_button != null and not _retry_button.pressed.is_connected(_on_retry_pressed):
		_retry_button.pressed.connect(_on_retry_pressed)
	if _menu_button != null and not _menu_button.pressed.is_connected(_on_menu_pressed):
		_menu_button.pressed.connect(_on_menu_pressed)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	_update_death_count(state)

func _update_death_count(state: Dictionary = {}) -> void:
	if _death_count_label == null:
		return

	var target_state: Dictionary = state
	if target_state.is_empty():
		var store := get_store()
		if store != null:
			target_state = store.get_state()

	var deaths: int = U_GameplaySelectors.get_death_count(target_state)
	var template: String = U_LOCALIZATION_UTILS.localize(&"menu.game_over.deaths")
	_death_count_label.text = template % deaths if template.contains("%") else "Deaths: %d" % deaths

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.game_over.title")
	if _retry_button != null:
		_retry_button.text = U_LOCALIZATION_UTILS.localize(&"menu.game_over.retry")
	if _menu_button != null:
		_menu_button.text = U_LOCALIZATION_UTILS.localize(&"menu.game_over.menu")
	_update_death_count()

func _on_retry_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_hide_immediately()
	_dispatch_soft_reset()
	_dispatch_navigation(U_NavigationActions.retry())

func _on_menu_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_hide_immediately()
	_dispatch_soft_reset()
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _hide_immediately() -> void:
	U_TRANSITION_OVERLAY_SNAP.hide_screen_and_snap_transition_overlay(self)

func _on_back_pressed() -> void:
	_on_retry_pressed()

func _dispatch_soft_reset() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_GameplayActions.reset_after_death())

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)
