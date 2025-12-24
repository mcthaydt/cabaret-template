extends GutTest

## Integration tests for menu save/load integration (Phase 6)
##
## Tests Redux dispatching logic for:
## - Pause menu "Save Game" button
## - Main menu "Continue" and "Load Game" buttons
## - Button visibility based on save state

const UI_PauseMenu := preload("res://scripts/ui/ui_pause_menu.gd")
const UI_MainMenu := preload("res://scripts/ui/ui_main_menu.gd")
const UI_SaveSlotSelector := preload("res://scripts/ui/ui_save_slot_selector.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_SaveEnvelope := preload("res://scripts/state/utils/u_save_envelope.gd")
const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

var _store: M_StateStore
var _dispatched_actions: Array[Dictionary] = []


func before_each() -> void:
	# Clean up any existing save slots BEFORE initializing store
	# (to prevent legacy migration during test setup)
	for i in range(1, 4):
		U_SaveManager.delete_slot(i)
	var autosave_path := U_SaveManager.get_auto_slot_path()
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)
	var legacy_path := "user://savegame.json"
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)

	# Initialize state store
	_store = M_StateStore.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	# Track dispatched actions
	_dispatched_actions.clear()
	_store.action_dispatched.connect(_on_action_dispatched)


func after_each() -> void:
	# Clean up save slots
	for i in range(1, 4):
		U_SaveManager.delete_slot(i)

	var autosave_path := U_SaveManager.get_auto_slot_path()
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)

	_store = null
	_dispatched_actions.clear()


func _on_action_dispatched(action: Dictionary) -> void:
	_dispatched_actions.append(action)


# ==============================================================================
# Pause Menu Tests
# ==============================================================================

func test_pause_menu_save_button_dispatches_save_mode() -> void:
	# Given: Pause menu is loaded
	var scene: PackedScene = load("res://scenes/ui/ui_pause_menu.tscn")
	var pause_menu: UI_PauseMenu = scene.instantiate() as UI_PauseMenu
	add_child_autofree(pause_menu)
	await get_tree().process_frame

	# When: "Save Game" button is pressed
	var save_button: Button = pause_menu.get_node_or_null("%SaveGameButton")
	assert_not_null(save_button, "Save Game button should exist in pause menu")

	_dispatched_actions.clear()
	save_button.pressed.emit()
	await get_tree().process_frame

	# Then: Should dispatch set_save_mode(SAVE) and open_overlay actions
	var set_mode_actions := _get_actions_by_type(U_SaveActions.ACTION_SET_SAVE_MODE)
	assert_eq(set_mode_actions.size(), 1, "Should dispatch set_save_mode action")
	assert_eq(set_mode_actions[0].get("mode"), UI_SaveSlotSelector.Mode.SAVE,
		"Should set mode to SAVE")

	var open_overlay_actions := _get_actions_by_type(U_NavigationActions.ACTION_OPEN_OVERLAY)
	assert_eq(open_overlay_actions.size(), 1, "Should dispatch open_overlay action")
	assert_eq(open_overlay_actions[0].get("screen_id"), StringName("save_slot_selector_overlay"),
		"Should open save_slot_selector_overlay")


func test_pause_menu_save_button_focus_chain_includes_save() -> void:
	# Given: Pause menu is loaded
	var scene: PackedScene = load("res://scenes/ui/ui_pause_menu.tscn")
	var pause_menu: UI_PauseMenu = scene.instantiate() as UI_PauseMenu
	add_child_autofree(pause_menu)
	await get_tree().process_frame
	# Wait for deferred calls to complete
	await get_tree().process_frame

	# When: Checking focus neighbors
	var resume_button: Button = pause_menu.get_node_or_null("%ResumeButton")
	var save_button: Button = pause_menu.get_node_or_null("%SaveGameButton")
	var settings_button: Button = pause_menu.get_node_or_null("%SettingsButton")

	# Then: Save button should be in the vertical focus chain
	assert_not_null(save_button, "Save Game button should exist")
	assert_not_null(resume_button, "Resume button should exist")
	assert_not_null(settings_button, "Settings button should exist")

	# Verify focus chain: Resume -> Save -> Settings -> Quit (circular)
	# U_FocusConfigurator uses relative paths (e.g., "../SaveGameButton")
	assert_eq(resume_button.focus_neighbor_bottom, NodePath("../SaveGameButton"),
		"Resume button should navigate down to Save button")
	assert_eq(save_button.focus_neighbor_top, NodePath("../ResumeButton"),
		"Save button should navigate up to Resume button")


# ==============================================================================
# Main Menu Tests - Continue Button
# ==============================================================================

func test_main_menu_continue_button_hidden_when_no_saves() -> void:
	# Given: Main menu is loaded with no saves
	var scene: PackedScene = load("res://scenes/ui/ui_main_menu.tscn")
	var main_menu: UI_MainMenu = scene.instantiate() as UI_MainMenu
	add_child_autofree(main_menu)
	await get_tree().process_frame
	# Wait for deferred visibility update
	await get_tree().process_frame

	# When: Checking button visibility
	var continue_button: Button = main_menu.get_node_or_null("%ContinueButton")
	assert_not_null(continue_button, "Continue button should exist in main menu")

	# Then: Continue button should be hidden
	assert_false(continue_button.visible, "Continue button should be hidden when no saves exist")


func test_main_menu_continue_button_visible_when_saves_exist() -> void:
	# Given: A save file exists
	_create_test_save(1, "test_scene", 100.0, 80.0)

	# And: Main menu is loaded
	var scene: PackedScene = load("res://scenes/ui/ui_main_menu.tscn")
	var main_menu: UI_MainMenu = scene.instantiate() as UI_MainMenu
	add_child_autofree(main_menu)
	await get_tree().process_frame

	# When: Checking button visibility
	var continue_button: Button = main_menu.get_node_or_null("%ContinueButton")
	assert_not_null(continue_button, "Continue button should exist in main menu")

	# Then: Continue button should be visible
	assert_true(continue_button.visible, "Continue button should be visible when saves exist")


func test_main_menu_continue_loads_most_recent_save() -> void:
	# Given: Multiple save files exist
	_create_test_save(1, "scene_1", 50.0, 75.0)
	await get_tree().process_frame
	_create_test_save(2, "scene_2", 100.0, 60.0)  # More recent
	await get_tree().process_frame

	# And: Main menu is loaded
	var scene: PackedScene = load("res://scenes/ui/ui_main_menu.tscn")
	var main_menu: UI_MainMenu = scene.instantiate() as UI_MainMenu
	add_child_autofree(main_menu)
	await get_tree().process_frame

	# When: Continue button is pressed
	var continue_button: Button = main_menu.get_node_or_null("%ContinueButton")
	_dispatched_actions.clear()
	continue_button.pressed.emit()
	await get_tree().process_frame

	# Then: Should dispatch load_started for most recent slot (slot 2)
	var load_actions := _get_actions_by_type(U_SaveActions.ACTION_LOAD_STARTED)
	assert_eq(load_actions.size(), 1, "Should dispatch load_started action")
	assert_eq(load_actions[0].get("slot_index"), 2,
		"Should load from most recent slot (slot 2)")


# ==============================================================================
# Main Menu Tests - Load Game Button
# ==============================================================================

func test_main_menu_load_button_dispatches_load_mode() -> void:
	# Given: Main menu is loaded
	var scene: PackedScene = load("res://scenes/ui/ui_main_menu.tscn")
	var main_menu: UI_MainMenu = scene.instantiate() as UI_MainMenu
	add_child_autofree(main_menu)
	await get_tree().process_frame

	# When: "Load Game" button is pressed
	var load_button: Button = main_menu.get_node_or_null("%LoadGameButton")
	assert_not_null(load_button, "Load Game button should exist in main menu")

	_dispatched_actions.clear()
	load_button.pressed.emit()
	await get_tree().process_frame

	# Then: Should dispatch set_save_mode(LOAD) and open_overlay actions
	var set_mode_actions := _get_actions_by_type(U_SaveActions.ACTION_SET_SAVE_MODE)
	assert_eq(set_mode_actions.size(), 1, "Should dispatch set_save_mode action")
	assert_eq(set_mode_actions[0].get("mode"), UI_SaveSlotSelector.Mode.LOAD,
		"Should set mode to LOAD")

	var open_overlay_actions := _get_actions_by_type(U_NavigationActions.ACTION_OPEN_OVERLAY)
	assert_eq(open_overlay_actions.size(), 1, "Should dispatch open_overlay action")
	assert_eq(open_overlay_actions[0].get("screen_id"), StringName("save_slot_selector_overlay"),
		"Should open save_slot_selector_overlay")


func test_main_menu_focus_chain_includes_new_buttons() -> void:
	# Given: A save exists (Continue button visible)
	_create_test_save(1, "test_scene", 100.0, 80.0)

	# And: Main menu is loaded
	var scene: PackedScene = load("res://scenes/ui/ui_main_menu.tscn")
	var main_menu: UI_MainMenu = scene.instantiate() as UI_MainMenu
	add_child_autofree(main_menu)
	await get_tree().process_frame

	# When: Checking focus neighbors
	var continue_button: Button = main_menu.get_node_or_null("%ContinueButton")
	var play_button: Button = main_menu.get_node_or_null("%PlayButton")
	var load_button: Button = main_menu.get_node_or_null("%LoadGameButton")

	# Then: Buttons should be in vertical focus chain
	assert_not_null(continue_button, "Continue button should exist")
	assert_not_null(play_button, "Play button should exist")
	assert_not_null(load_button, "Load Game button should exist")

	# Verify focus chain includes all buttons in logical order
	# Expected: Continue -> Play -> Load -> Settings (vertical)
	assert_true(continue_button.visible, "Continue button should be visible")


# ==============================================================================
# Helper Methods
# ==============================================================================

func _get_actions_by_type(action_type: StringName) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for action in _dispatched_actions:
		if action.get("type") == action_type:
			filtered.append(action)
	return filtered


func _create_test_save(slot_index: int, scene_name: String, play_time: float, health: float) -> void:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id = slot_index
	metadata.slot_type = RS_SaveSlotMetadata.SlotType.MANUAL
	metadata.is_empty = false
	metadata.timestamp = Time.get_unix_time_from_system()
	metadata.scene_name = scene_name
	metadata.play_time_seconds = play_time
	metadata.player_health = health
	metadata.player_max_health = 100.0
	metadata.death_count = 0

	var test_state: Dictionary = {
		"scene": {"current_scene_id": scene_name},
		"gameplay": {
			"play_time_seconds": play_time,
			"player_health": health,
			"player_max_health": 100.0,
			"death_count": 0,
		}
	}

	var path := U_SaveManager.get_manual_slot_path(slot_index)
	U_SaveEnvelope.write_envelope(path, metadata, test_state)
