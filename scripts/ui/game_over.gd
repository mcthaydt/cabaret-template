extends Control

## Game Over screen controller (Phase 9)
##
## Shows total death count and provides Retry/Menu actions:
## - Retry: Soft reset player state and transition back to exterior.
## - Menu: Return to main menu scene.

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")

@onready var death_count_label: Label = $MarginContainer/VBoxContainer/DeathCountLabel
@onready var retry_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RetryButton
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

	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	_update_death_count()

func _exit_tree() -> void:
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	_update_death_count()

func _update_death_count() -> void:
	if death_count_label == null:
		return

	var deaths: int = 0
	if _store != null:
		var state: Dictionary = _store.get_state()
		var gameplay: Dictionary = state.get("gameplay", {})
		deaths = int(gameplay.get("death_count", 0))

	death_count_label.text = "Deaths: %d" % deaths

func _on_retry_pressed() -> void:
	_dispatch_soft_reset()
	_transition_to_scene(StringName("exterior"))

func _on_menu_pressed() -> void:
	_dispatch_soft_reset()
	_transition_to_scene(StringName("main_menu"))

func _dispatch_soft_reset() -> void:
	if _store == null:
		return
	_store.dispatch(U_GameplayActions.reset_after_death())

func _transition_to_scene(scene_id: StringName) -> void:
	if _scene_manager == null:
		return
	_scene_manager.transition_to_scene(scene_id, "fade", M_SceneManager.Priority.HIGH)
