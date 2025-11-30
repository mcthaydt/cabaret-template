@icon("res://resources/editor_icons/utility.svg")
extends BaseMenuScreen

## Main Menu UI Controller (state-driven)
##
## Responds to navigation slice updates to show the correct panel
## and dispatches navigation actions for play/settings flows.

const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")

const PANEL_MAIN := StringName("menu/main")
const PANEL_SETTINGS := StringName("menu/settings")
const DEFAULT_GAMEPLAY_SCENE := StringName("exterior")

@onready var _main_panel: Control = %MainPanel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _play_button: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_back_button: Button = %SettingsBackButton

var _store_unsubscribe: Callable = Callable()
var _active_panel: StringName = StringName()

func _on_panel_ready() -> void:
	_connect_buttons()
	_configure_focus_neighbors()
	var store := get_store()
	if store == null:
		return
	if _store_unsubscribe == Callable() or not _store_unsubscribe.is_valid():
		_store_unsubscribe = store.subscribe(_on_state_changed)
	_on_state_changed({}, store.get_state())

func _configure_focus_neighbors() -> void:
	# Configure main panel button focus (vertical navigation with wrapping)
	var main_buttons: Array[Control] = []
	if _play_button != null:
		main_buttons.append(_play_button)
	if _settings_button != null:
		main_buttons.append(_settings_button)

	if not main_buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(main_buttons, true)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()

func _connect_buttons() -> void:
	if _play_button != null and not _play_button.pressed.is_connected(_on_play_pressed):
		_play_button.pressed.connect(_on_play_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _settings_back_button != null and not _settings_back_button.pressed.is_connected(_on_settings_back_pressed):
		_settings_back_button.pressed.connect(_on_settings_back_pressed)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	var navigation_slice: Dictionary = state.get("navigation", {})
	var desired_panel: StringName = U_NavigationSelectors.get_active_menu_panel(navigation_slice)
	_update_panel_state(desired_panel)

func _update_panel_state(panel_id: StringName) -> void:
	var resolved_panel: StringName = panel_id
	if resolved_panel == StringName(""):
		resolved_panel = PANEL_MAIN

	# Only respond to main menu panels (menu/*)
	# Ignore panels from other contexts (like pause/root from gameplay)
	if not _is_main_menu_panel(resolved_panel):
		return

	if resolved_panel == _active_panel:
		return
	_active_panel = resolved_panel
	_set_panel_visibility(resolved_panel == PANEL_MAIN)
	_focus_active_panel()

## Check if a panel ID belongs to the main menu
func _is_main_menu_panel(panel_id: StringName) -> bool:
	# Main menu panels all start with "menu/"
	var panel_str: String = str(panel_id)
	return panel_str.begins_with("menu/")

func _set_panel_visibility(show_main: bool) -> void:
	if _main_panel != null:
		_main_panel.visible = show_main
	if _settings_panel != null:
		_settings_panel.visible = not show_main

func _focus_active_panel() -> void:
	call_deferred("_apply_focus_after_layout")

func _apply_focus_after_layout() -> void:
	var focus_target: Control = _get_first_focusable()
	if focus_target != null and focus_target.is_inside_tree():
		focus_target.grab_focus()

func _on_play_pressed() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.start_game(DEFAULT_GAMEPLAY_SCENE))

func _on_settings_pressed() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_menu_panel(PANEL_SETTINGS))

func _on_settings_back_pressed() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_menu_panel(PANEL_MAIN))

func _on_back_pressed() -> void:
	if _active_panel != PANEL_MAIN:
		var store := get_store()
		if store != null:
			store.dispatch(U_NavigationActions.set_menu_panel(PANEL_MAIN))
