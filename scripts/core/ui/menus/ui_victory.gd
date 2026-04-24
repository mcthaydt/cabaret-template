@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_menu_screen.gd"
class_name UI_Victory

## Victory screen controller (Phase 9)
##
## Displays completion stats and dispatches navigation actions:
## - Continue: Return to configured gameplay retry scene via run/reset orchestration.
## - Credits: Skip to credits (visible after completion).
## - Menu: Return to main menu.


const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")
const U_RUN_ACTIONS := preload("res://scripts/core/state/actions/u_run_actions.gd")
const U_TRANSITION_OVERLAY_SNAP := preload("res://scripts/core/scene_management/helpers/u_transition_overlay_snap.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")
const DEBUG_VICTORY_TRACE := false

@onready var _title_label: Label = %TitleLabel
@onready var _completed_label: Label = %CompletedLabel
@onready var _button_row: HBoxContainer = $MarginContainer/CenterContainer/MainPanel/MainPanelPadding/VBoxContainer/ButtonRow
@onready var _content_vbox: VBoxContainer = $MarginContainer/CenterContainer/MainPanel/MainPanelPadding/VBoxContainer
@onready var _background: ColorRect = $Background
@onready var _continue_button: Button = %ContinueButton
@onready var _credits_button: Button = %CreditsButton
@onready var _menu_button: Button = %MenuButton

var _store_unsubscribe: Callable = Callable()

func _debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print("[VictoryDebug][UI_Victory] %s" % message)

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_update_display(store.get_state())

func _on_panel_ready() -> void:
	_apply_theme_tokens()
	_connect_buttons()
	_localize_labels()
	_configure_focus_neighbors()
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
		_title_label.add_theme_color_override(&"font_color", config.success)
	if _completed_label != null:
		_completed_label.add_theme_font_size_override(&"font_size", config.heading)
		_completed_label.add_theme_color_override(&"font_color", config.text_secondary)

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
	# Configure horizontal focus navigation for victory buttons with wrapping
	var buttons: Array[Control] = []
	if _continue_button != null:
		buttons.append(_continue_button)
	if _credits_button != null and _credits_button.visible and not _credits_button.disabled:
		buttons.append(_credits_button)
	if _menu_button != null:
		buttons.append(_menu_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()

func _connect_buttons() -> void:
	if _continue_button != null and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if _credits_button != null and not _credits_button.pressed.is_connected(_on_credits_pressed):
		_credits_button.pressed.connect(_on_credits_pressed)
	if _menu_button != null and not _menu_button.pressed.is_connected(_on_menu_pressed):
		_menu_button.pressed.connect(_on_menu_pressed)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	_update_display(state)

func _update_display(state: Dictionary = {}) -> void:
	if _completed_label == null:
		return

	var target_state: Dictionary = state
	if target_state.is_empty():
		var store := get_store()
		if store != null:
			target_state = store.get_state()

	var completed_areas: Array = U_GameplaySelectors.get_completed_areas(target_state)
	var completed_count: int = completed_areas.size()
	var game_completed: bool = U_GameplaySelectors.get_game_completed(target_state)

	var template: String = U_LOCALIZATION_UTILS.localize(&"menu.victory.completed_areas")
	_completed_label.text = template % completed_count if template.contains("%") else "Completed Areas: %d" % completed_count

	if _credits_button != null:
		_credits_button.visible = game_completed
		_credits_button.disabled = not game_completed
	_configure_focus_neighbors()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.victory.title")
	if _continue_button != null:
		_continue_button.text = U_LOCALIZATION_UTILS.localize(&"menu.victory.continue")
	if _credits_button != null:
		_credits_button.text = U_LOCALIZATION_UTILS.localize(&"menu.victory.credits")
	if _menu_button != null:
		_menu_button.text = U_LOCALIZATION_UTILS.localize(&"menu.victory.menu")
	_update_display()

func _on_continue_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_hide_immediately()
	_dispatch_run_reset(StringName("retry"))

func _on_credits_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_hide_immediately()
	_reset_game_progress()
	_dispatch_navigation(U_NavigationActions.skip_to_credits())

func _on_menu_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_hide_immediately()
	_reset_game_progress()
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _hide_immediately() -> void:
	# Snap the transition overlay to fully opaque so the screen goes black
	# instantly. Trans_Fade.execute_fade_out will detect alpha == 1.0 and
	# skip the fade-out animation, giving a clean cut-to-black → fade-in.
	U_TRANSITION_OVERLAY_SNAP.hide_screen_and_snap_transition_overlay(self)

func _on_back_pressed() -> void:
	_on_credits_pressed()

func _reset_game_progress() -> void:
	var store := get_store()
	if store == null:
		_debug_log("reset_progress skipped: no store")
		return
	var before_state: Dictionary = store.get_state()
	_debug_log(
		"dispatching gameplay/reset_progress before gameplay.completed_areas=%s gameplay.game_completed=%s objectives.statuses=%s"
		% [
			str(U_GameplaySelectors.get_completed_areas(before_state)),
			str(U_GameplaySelectors.get_game_completed(before_state)),
			str(U_ObjectivesSelectors.get_statuses_snapshot(before_state)),
		]
	)
	store.dispatch(U_GameplayActions.reset_progress())
	var after_state: Dictionary = store.get_state()
	_debug_log(
		"after gameplay/reset_progress gameplay.completed_areas=%s gameplay.game_completed=%s objectives.statuses=%s"
		% [
			str(U_GameplaySelectors.get_completed_areas(after_state)),
			str(U_GameplaySelectors.get_game_completed(after_state)),
			str(U_ObjectivesSelectors.get_statuses_snapshot(after_state)),
		]
	)
	_update_display(store.get_state())

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)

func _dispatch_run_reset(next_route: StringName = StringName("retry")) -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_RUN_ACTIONS.reset_run(next_route))
