@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"

## Settings Menu UI Controller
##
## Runs as either an overlay (pause → settings) or as embedded UI in the main
## menu. Uses navigation actions for overlay flows and SceneManager transitions
## when opened from the main menu.

const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")

@onready var _back_button: Button = $VBoxContainer/BackButton
@onready var _input_profiles_button: Button = %InputProfilesButton
@onready var _gamepad_settings_button: Button = %GamepadSettingsButton
@onready var _touchscreen_settings_button: Button = %TouchscreenSettingsButton
@onready var _rebind_controls_button: Button = %RebindControlsButton

const SETTINGS_OVERLAY_ID := StringName("settings_menu_overlay")
const OVERLAY_INPUT_PROFILE := StringName("input_profile_selector")
const OVERLAY_GAMEPAD_SETTINGS := StringName("gamepad_settings")
const OVERLAY_TOUCHSCREEN_SETTINGS := StringName("touchscreen_settings")
const OVERLAY_INPUT_REBINDING := StringName("input_rebinding")

func _on_store_ready(store: M_StateStore) -> void:
	if store != null and not store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.connect(_on_slice_updated)
		_update_button_visibility(store.get_state())

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

func _on_panel_ready() -> void:
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _input_profiles_button != null and not _input_profiles_button.pressed.is_connected(_on_input_profiles_pressed):
		_input_profiles_button.pressed.connect(_on_input_profiles_pressed)
	if _gamepad_settings_button != null and not _gamepad_settings_button.pressed.is_connected(_on_gamepad_settings_pressed):
		_gamepad_settings_button.pressed.connect(_on_gamepad_settings_pressed)
	if _touchscreen_settings_button != null and not _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed):
		_touchscreen_settings_button.pressed.connect(_on_touchscreen_settings_pressed)
	if _rebind_controls_button != null and not _rebind_controls_button.pressed.is_connected(_on_rebind_controls_pressed):
		_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
	_update_back_button_label()
	var store := get_store()
	if store != null:
		_update_button_visibility(store.get_state())

func _on_slice_updated(_slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return
	_update_button_visibility(store.get_state())

func _on_back_pressed() -> void:
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var top_overlay: StringName = U_NavigationSelectors.get_top_overlay_id(nav_slice)
	if top_overlay == SETTINGS_OVERLAY_ID:
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		store.dispatch(U_NavigationActions.return_to_main_menu())

func _on_input_profiles_pressed() -> void:
	_open_settings_target(OVERLAY_INPUT_PROFILE, StringName("input_profile_selector"))

func _on_gamepad_settings_pressed() -> void:
	_open_settings_target(OVERLAY_GAMEPAD_SETTINGS, StringName("gamepad_settings"))

func _on_touchscreen_settings_pressed() -> void:
	_open_settings_target(OVERLAY_TOUCHSCREEN_SETTINGS, StringName("touchscreen_settings"))

func _on_rebind_controls_pressed() -> void:
	_open_settings_target(OVERLAY_INPUT_REBINDING, StringName("input_rebinding"))

func _update_button_visibility(state: Dictionary) -> void:
	var has_gamepad: bool = U_InputSelectors.is_gamepad_connected(state)
	var is_mobile: bool = OS.has_feature("mobile")

	if _gamepad_settings_button != null:
		_gamepad_settings_button.visible = has_gamepad
	if _touchscreen_settings_button != null:
		_touchscreen_settings_button.visible = is_mobile

func _open_settings_target(overlay_id: StringName, scene_id: StringName) -> void:
	var store := get_store()
	if store == null:
		_transition_to_scene(scene_id)
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	# Gameplay overlay flow: open as overlay above settings overlay.
	if shell == StringName("gameplay") and not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.open_overlay(overlay_id))
		return

	# Menu flow (main menu/settings scene): transition to standalone UI scene.
	_transition_to_scene(scene_id)

func _transition_to_scene(scene_id: StringName) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var managers := tree.get_nodes_in_group("scene_manager")
	if managers.is_empty():
		return
	var scene_manager := managers[0] as M_SceneManager
	if scene_manager == null:
		return
	scene_manager.transition_to_scene(scene_id, "fade", M_SceneManager.Priority.HIGH)

func _update_back_button_label() -> void:
	if _back_button == null:
		return

	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var top_overlay: StringName = U_NavigationSelectors.get_top_overlay_id(nav_slice)
	var is_overlay: bool = top_overlay == SETTINGS_OVERLAY_ID
	_back_button.text = "Back" if is_overlay else "Back to Main Menu"
