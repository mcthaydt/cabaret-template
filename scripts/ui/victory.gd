@icon("res://resources/editor_icons/utility.svg")
extends Control

## Victory screen controller (Phase 9)
##
## Displays completion stats and routes buttons:
## - Continue: Return to gameplay hub.
## - Credits: Open credits (visible after full completion).
## - Menu: Return to main menu.

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")

@onready var completed_label: Label = $MarginContainer/VBoxContainer/CompletedLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ContinueButton
@onready var credits_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CreditsButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/ButtonRow/MenuButton

var _store: M_StateStore = null
var _scene_manager: M_SceneManager = null

func _ready() -> void:
	await get_tree().process_frame

	_store = U_StateUtils.get_store(self)
	var managers := get_tree().get_nodes_in_group("scene_manager")
	if managers.size() > 0:
		_scene_manager = managers[0] as M_SceneManager

	if _store != null:
		_store.slice_updated.connect(_on_slice_updated)

	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	_update_display()

func _exit_tree() -> void:
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	_update_display()

func _update_display() -> void:
	var completed_count: int = 0
	var game_completed: bool = false

	if _store != null:
		var state: Dictionary = _store.get_state()
		var gameplay: Dictionary = state.get("gameplay", {})

		var completed_areas: Array = gameplay.get("completed_areas", [])
		if completed_areas is Array:
			completed_count = (completed_areas as Array).size()
		game_completed = bool(gameplay.get("game_completed", false))

	if completed_label != null:
		completed_label.text = "Completed Areas: %d" % completed_count

	if credits_button != null:
		credits_button.visible = game_completed
		credits_button.disabled = not game_completed

func _on_continue_pressed() -> void:
	_reset_game_progress()
	# Return to hub (exterior) per integration tests
	_transition_to_scene(StringName("exterior"))

func _on_credits_pressed() -> void:
	_reset_game_progress()
	_transition_to_scene(StringName("credits"))

func _on_menu_pressed() -> void:
	_reset_game_progress()
	_transition_to_scene(StringName("main_menu"))

func _transition_to_scene(scene_id: StringName) -> void:
	if _scene_manager == null:
		return
	_scene_manager.transition_to_scene(scene_id, "fade", M_SceneManager.Priority.HIGH)

func _reset_game_progress() -> void:
	if _store == null:
		return
	_store.dispatch(U_GameplayActions.reset_progress())
	_update_display()
