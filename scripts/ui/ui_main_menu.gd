@icon("res://resources/editor_icons/utility.svg")
extends BaseMenuScreen
class_name UI_MainMenu

## Main Menu UI Controller (state-driven)
##
## Responds to navigation slice updates to show the correct panel
## and dispatches navigation actions for play/settings flows.

const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const UI_SaveSlotSelector := preload("res://scripts/ui/ui_save_slot_selector.gd")

const PANEL_MAIN := StringName("menu/main")
const PANEL_SETTINGS := StringName("menu/settings")
const DEFAULT_GAMEPLAY_SCENE := StringName("exterior")
const OVERLAY_SAVE_SELECTOR := StringName("save_slot_selector_overlay")

@onready var _main_panel: Control = %MainPanel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _play_button: Button = %PlayButton
@onready var _load_button: Button = %LoadGameButton
@onready var _settings_button: Button = %SettingsButton

var _store_unsubscribe: Callable = Callable()
var _active_panel: StringName = StringName()
var _previous_overlay_stack: Array = []

func _on_panel_ready() -> void:
	_connect_buttons()
	# Update button visibility after scene tree is ready
	call_deferred("_update_button_visibility")
	call_deferred("_configure_focus_neighbors")
	var store := get_store()
	if store == null:
		return
	if _store_unsubscribe == Callable() or not _store_unsubscribe.is_valid():
		_store_unsubscribe = store.subscribe(_on_state_changed)
	_on_state_changed({}, store.get_state())

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
	# Add buttons in display order (Continue only added if visible)
	if _continue_button != null and _continue_button.visible:
		main_buttons.append(_continue_button)
	if _play_button != null:
		main_buttons.append(_play_button)
	if _load_button != null:
		main_buttons.append(_load_button)
	if _settings_button != null:
		main_buttons.append(_settings_button)

	if not main_buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(main_buttons, true)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()

func _connect_buttons() -> void:
	if _continue_button != null and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if _play_button != null and not _play_button.pressed.is_connected(_on_play_pressed):
		_play_button.pressed.connect(_on_play_pressed)
	if _load_button != null and not _load_button.pressed.is_connected(_on_load_pressed):
		_load_button.pressed.connect(_on_load_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	var navigation_slice: Dictionary = state.get("navigation", {})
	var desired_panel: StringName = U_NavigationSelectors.get_active_menu_panel(navigation_slice)
	var current_overlay_stack: Array = navigation_slice.get("overlay_stack", [])

	# Check if overlay just closed (stack went from non-empty to empty)
	var overlay_just_closed: bool = _previous_overlay_stack.size() > 0 and current_overlay_stack.is_empty()
	_previous_overlay_stack = current_overlay_stack.duplicate()

	# Update panel state (handles panel changes)
	_update_panel_state(desired_panel)

	# Restore focus if overlay just closed while on main menu
	if overlay_just_closed and _active_panel == PANEL_MAIN:
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
	print("UI_MainMenu: Continue button pressed")
	var store := get_store()
	if store == null:
		print("UI_MainMenu: ERROR - No store found!")
		return
	# Get most recent save slot
	var most_recent_slot: int = U_SaveManager.get_most_recent_slot()
	print("UI_MainMenu: Most recent slot: ", most_recent_slot)
	if most_recent_slot < 0:
		push_warning("UI_MainMenu: Continue pressed but no saves exist")
		return
	# Dispatch load action for most recent slot
	print("UI_MainMenu: Dispatching load_started for slot ", most_recent_slot)
	store.dispatch(U_SaveActions.load_started(most_recent_slot))

func _on_play_pressed() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.start_game(DEFAULT_GAMEPLAY_SCENE))

func _on_load_pressed() -> void:
	print("UI_MainMenu: Load Game button pressed")
	var store := get_store()
	if store == null:
		print("UI_MainMenu: ERROR - No store found!")
		return
	# Dispatch mode BEFORE opening overlay (prevents Bug #8 from LESSONS_LEARNED.md)
	print("UI_MainMenu: Dispatching set_save_mode(LOAD) and opening overlay")
	store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.LOAD))
	store.dispatch(U_NavigationActions.open_overlay(OVERLAY_SAVE_SELECTOR))

func _on_settings_pressed() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_menu_panel(PANEL_SETTINGS))

func _on_back_pressed() -> void:
	if _active_panel != PANEL_MAIN:
		var store := get_store()
		if store != null:
			store.dispatch(U_NavigationActions.set_menu_panel(PANEL_MAIN))

func _update_button_visibility() -> void:
	# Show Continue button only if saves exist
	var has_saves: bool = U_SaveManager.has_any_save()
	if _continue_button != null:
		_continue_button.visible = has_saves
