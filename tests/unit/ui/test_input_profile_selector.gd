extends GutTest

## TDD regression test for InputProfileSelector navigation.
##
## Bug: Pressing ui_up/ui_down while ProfileButton is focused does nothing; user must press ui_accept.
## Expected: ui_up/ui_down cycles profiles immediately when ProfileButton has focus.

const INPUT_PROFILE_SELECTOR_SCENE := preload("res://scenes/ui/ui_input_profile_selector.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")

class MockInputProfileManager:
	extends Node

	signal profile_switched(profile_id: String)

	func get_available_profile_ids() -> Array[String]:
		return ["profile_a", "profile_b", "profile_c"]

	func switch_profile(profile_id: String) -> void:
		profile_switched.emit(profile_id)

var _manager: Node
var _store: M_StateStore

func before_each() -> void:
	_store = M_StateStore.new()
	_store.add_to_group("state_store")
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)

	_manager = MockInputProfileManager.new()
	_manager.add_to_group("input_profile_manager")
	add_child_autofree(_manager)
	await get_tree().process_frame

func test_ui_down_cycles_profile_when_profile_button_focused() -> void:
	var overlay := INPUT_PROFILE_SELECTOR_SCENE.instantiate() as Control
	add_child_autofree(overlay)
	await wait_process_frames(4)

	var profile_button := overlay.get_node("HBoxContainer/ProfileButton") as Button
	assert_not_null(profile_button, "ProfileButton must exist")

	profile_button.grab_focus()
	await get_tree().process_frame

	var initial_text := profile_button.text
	assert_true(not initial_text.is_empty(), "ProfileButton should have initial profile text")

	var down_event := InputEventAction.new()
	down_event.action = "ui_down"
	down_event.pressed = true

	overlay._unhandled_input(down_event)
	await get_tree().process_frame

	assert_ne(profile_button.text, initial_text,
		"ui_down should cycle profile without requiring ui_accept")
