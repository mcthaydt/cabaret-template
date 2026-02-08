@icon("res://assets/editor_icons/icn_utility.svg")
extends BaseMenuScreen
class_name UI_Victory

## Victory screen controller (Phase 9)
##
## Displays completion stats and dispatches navigation actions:
## - Continue: Return to gameplay hub (alleyway).
## - Credits: Skip to credits (visible after completion).
## - Menu: Return to main menu.


@onready var _completed_label: Label = $MarginContainer/VBoxContainer/CompletedLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ContinueButton
@onready var _credits_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CreditsButton
@onready var _menu_button: Button = $MarginContainer/VBoxContainer/ButtonRow/MenuButton

const HUB_SCENE_ID := StringName("alleyway")

var _store_unsubscribe: Callable = Callable()

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_update_display(store.get_state())

func _on_panel_ready() -> void:
	_connect_buttons()
	_configure_focus_neighbors()
	_update_display()

func _configure_focus_neighbors() -> void:
	# Configure horizontal focus navigation for victory buttons with wrapping
	var buttons: Array[Control] = []
	if _continue_button != null:
		buttons.append(_continue_button)
	if _credits_button != null:
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

	var gameplay: Dictionary = target_state.get("gameplay", {})
	var completed_areas: Array = gameplay.get("completed_areas", [])
	var completed_count: int = 0
	if completed_areas is Array:
		completed_count = (completed_areas as Array).size()
	var game_completed: bool = bool(gameplay.get("game_completed", false))

	_completed_label.text = "Completed Areas: %d" % completed_count

	if _credits_button != null:
		_credits_button.visible = game_completed
		_credits_button.disabled = not game_completed

func _on_continue_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_reset_game_progress()
	_dispatch_navigation(U_NavigationActions.retry(HUB_SCENE_ID))

func _on_credits_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_reset_game_progress()
	_dispatch_navigation(U_NavigationActions.skip_to_credits())

func _on_menu_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_reset_game_progress()
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _on_back_pressed() -> void:
	_on_credits_pressed()

func _reset_game_progress() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_GameplayActions.reset_progress())
	_update_display(store.get_state())

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)
