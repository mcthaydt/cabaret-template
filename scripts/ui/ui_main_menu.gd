@icon("res://assets/editor_icons/utility.svg")
extends BaseMenuScreen
class_name UI_MainMenu

## Main Menu UI Controller (state-driven)
##
## Responds to navigation slice updates to show the correct panel
## and dispatches navigation actions for play/settings flows.

const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const I_SaveManager := preload("res://scripts/interfaces/i_save_manager.gd")

const PANEL_MAIN := StringName("menu/main")
const PANEL_SETTINGS := StringName("menu/settings")
const DEFAULT_GAMEPLAY_SCENE := StringName("exterior")
const OVERLAY_SAVE_LOAD := StringName("save_load_menu_overlay")

@onready var _main_panel: Control = %MainPanel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _new_game_confirm_dialog: ConfirmationDialog = %NewGameConfirmDialog

var _save_manager: Node = null  # M_SaveManager
var _new_game_confirmation_pending: bool = false

var _store_unsubscribe: Callable = Callable()
var _active_panel: StringName = StringName()

func _on_panel_ready() -> void:
	_discover_save_manager()
	_update_button_visibility()
	_connect_buttons()
	_configure_focus_neighbors()
	var store := get_store()
	if store == null:
		return
	if _store_unsubscribe == Callable() or not _store_unsubscribe.is_valid():
		_store_unsubscribe = store.subscribe(_on_state_changed)
	_on_state_changed({}, store.get_state())

func _discover_save_manager() -> void:
	_save_manager = U_ServiceLocator.try_get_service(StringName("save_manager"))

func _update_button_visibility() -> void:
	# Show Continue button only if saves exist
	var has_saves: bool = false
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager != null:
		has_saves = typed_save_manager.has_any_saves()

	if _continue_button != null:
		_continue_button.visible = has_saves

	# Hide Quit button on mobile (mobile apps should use OS close mechanisms)
	if _quit_button != null:
		_quit_button.visible = not OS.has_feature("mobile")

func _process(delta: float) -> void:
	# Only run analog stick navigation from the main panel.
	# When the settings panel (SettingsMenu) is active, its own BaseMenuScreen
	# instance handles analog navigation to avoid double-processing.
	if _active_panel == PANEL_SETTINGS:
		return
	super._process(delta)

func _configure_focus_neighbors() -> void:
	# Configure main panel button focus (vertical navigation with wrapping)
	var main_buttons: Array[Control] = []
	if _continue_button != null and _continue_button.visible:
		main_buttons.append(_continue_button)
	if _new_game_button != null:
		main_buttons.append(_new_game_button)
	if _load_game_button != null:
		main_buttons.append(_load_game_button)
	if _settings_button != null:
		main_buttons.append(_settings_button)
	if _quit_button != null and _quit_button.visible:
		main_buttons.append(_quit_button)

	if not main_buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(main_buttons, true)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()

func _connect_buttons() -> void:
	if _continue_button != null and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if _new_game_button != null and not _new_game_button.pressed.is_connected(_on_new_game_pressed):
		_new_game_button.pressed.connect(_on_new_game_pressed)
	if _load_game_button != null and not _load_game_button.pressed.is_connected(_on_load_game_pressed):
		_load_game_button.pressed.connect(_on_load_game_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)

	if _new_game_confirm_dialog != null:
		if not _new_game_confirm_dialog.confirmed.is_connected(_on_new_game_confirmed):
			_new_game_confirm_dialog.confirmed.connect(_on_new_game_confirmed)
		if not _new_game_confirm_dialog.canceled.is_connected(_on_new_game_canceled):
			_new_game_confirm_dialog.canceled.connect(_on_new_game_canceled)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	var navigation_slice: Dictionary = state.get("navigation", {})
	var desired_panel: StringName = U_NavigationSelectors.get_active_menu_panel(navigation_slice)
	_update_panel_state(desired_panel)

	# Restore main panel visibility and focus when overlay closes (in main_menu shell)
	var shell: StringName = navigation_slice.get("shell", StringName(""))
	var overlay_stack: Array = navigation_slice.get("overlay_stack", [])
	if shell == StringName("main_menu") and not overlay_stack.is_empty():
		# Hide main menu options while overlays are open (e.g., Save/Load).
		if _main_panel != null:
			_main_panel.visible = false
	elif shell == StringName("main_menu") and overlay_stack.is_empty():
		# Restore visibility if panel was hidden
		if _main_panel != null and not _main_panel.visible and _active_panel == PANEL_MAIN:
			_main_panel.visible = true
		# BUG FIX: Always restore focus when returning from overlay, even if panel stayed visible
		if _active_panel == PANEL_MAIN:
			_focus_active_panel()

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

func _on_continue_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	# Load the most recent save
	if _save_manager == null:
		push_error("UI_MainMenu: Save manager not available for Continue")
		return

	var most_recent_slot: StringName = _save_manager.get_most_recent_save_slot()
	if most_recent_slot == StringName(""):
		push_warning("UI_MainMenu: No saves found for Continue")
		return

	# Hide main menu content immediately for loading feedback
	if _main_panel != null:
		_main_panel.visible = false

	# Load the save (scene transition will close main menu)
	var result: Error = _save_manager.load_from_slot(most_recent_slot)

	# If load failed, restore visibility
	if result != OK:
		if _main_panel != null:
			_main_panel.visible = true
		push_error("UI_MainMenu: Failed to load save (error %d)" % result)

func _on_new_game_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	var store := get_store()
	if store == null:
		return

	if _should_confirm_new_game():
		_show_new_game_confirmation()
		return

	store.dispatch(U_NavigationActions.start_game(DEFAULT_GAMEPLAY_SCENE))

func _should_confirm_new_game() -> bool:
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager == null:
		return false
	return typed_save_manager.has_any_saves()

func _show_new_game_confirmation() -> void:
	_new_game_confirmation_pending = true
	if _new_game_confirm_dialog == null:
		return
	_new_game_confirm_dialog.popup_centered()

func _on_new_game_confirmed() -> void:
	U_UISoundPlayer.play_confirm()

	_new_game_confirmation_pending = false
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.start_game(DEFAULT_GAMEPLAY_SCENE))

func _on_new_game_canceled() -> void:
	U_UISoundPlayer.play_cancel()
	_new_game_confirmation_pending = false

func _on_load_game_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	var store := get_store()
	if store == null:
		return

	# Hide main panel while overlay is open
	if _main_panel != null:
		_main_panel.visible = false

	# Set mode to "load" and open the save/load overlay
	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
	store.dispatch(U_NavigationActions.open_overlay(OVERLAY_SAVE_LOAD))

func _on_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_menu_panel(PANEL_SETTINGS))

func _on_quit_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	# Quit the game
	get_tree().quit()

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	if _active_panel != PANEL_MAIN:
		var store := get_store()
		if store != null:
			store.dispatch(U_NavigationActions.set_menu_panel(PANEL_MAIN))
