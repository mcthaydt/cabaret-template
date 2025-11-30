@icon("res://resources/editor_icons/utility.svg")
extends BaseMenuScreen

## Game Over screen controller (Phase 9)
##
## Shows total death count and dispatches navigation actions:
## - Retry: Soft reset player state and return to last gameplay scene.
## - Menu: Soft reset and return to main menu.

const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")

@onready var _death_count_label: Label = $MarginContainer/VBoxContainer/DeathCountLabel
@onready var _retry_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RetryButton
@onready var _menu_button: Button = $MarginContainer/VBoxContainer/ButtonRow/MenuButton

var _store_unsubscribe: Callable = Callable()

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_update_death_count(store.get_state())

func _on_panel_ready() -> void:
	_connect_buttons()
	_configure_focus_neighbors()
	_update_death_count()

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

	var gameplay: Dictionary = target_state.get("gameplay", {})
	var deaths: int = int(gameplay.get("death_count", 0))
	_death_count_label.text = "Deaths: %d" % deaths

func _on_retry_pressed() -> void:
	_dispatch_soft_reset()
	_dispatch_navigation(U_NavigationActions.retry())

func _on_menu_pressed() -> void:
	_dispatch_soft_reset()
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

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
