@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_PauseMenu

## Pause Menu - overlay wired into navigation actions
##
## Buttons dispatch navigation actions instead of calling Scene Manager directly.


const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")

const OVERLAY_SETTINGS := StringName("settings_menu_overlay")
const OVERLAY_SAVE_LOAD := StringName("save_load_menu_overlay")

@onready var _title_label: Label = %TitleLabel
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _quit_button: Button = %QuitButton

var _last_device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _consume_next_nav: bool = false

func _ready() -> void:
	super._ready()
	_configure_focus_neighbors()

func _configure_focus_neighbors() -> void:
	var buttons: Array[Control] = []
	if _resume_button != null:
		buttons.append(_resume_button)
	if _settings_button != null:
		buttons.append(_settings_button)
	if _save_button != null:
		buttons.append(_save_button)
	if _load_button != null:
		buttons.append(_load_button)
	if _quit_button != null:
		buttons.append(_quit_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(buttons, true)

func _on_store_ready(store_ref: M_StateStore) -> void:
	if store_ref != null:
		store_ref.slice_updated.connect(_on_slice_updated)

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return

	if slice_name == StringName("navigation"):
		var nav_state: Dictionary = store.get_slice(StringName("navigation"))
		var shell: StringName = nav_state.get("shell", StringName())
		if shell != StringName("gameplay"):
			visible = false

		# BUG FIX: Restore focus when overlay closes (in gameplay shell)
		# When save/load menu or settings closes, refocus the pause menu
		var overlay_stack: Array = nav_state.get("overlay_stack", [])
		if shell == StringName("gameplay") and overlay_stack.is_empty() and visible:
			_focus_resume()

	# Preserve analog navigation behavior for gamepad switches
	var state: Dictionary = store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var previous_type: int = _last_device_type
	_last_device_type = device_type

	# Only consume first input when resuming FROM touch to gamepad.
	if device_type == M_InputDeviceManager.DeviceType.GAMEPAD \
			and previous_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN:
		reset_analog_navigation()
		_consume_next_nav = true
		_focus_resume()

func _navigate_focus(direction: StringName) -> void:
	if _consume_next_nav:
		_consume_next_nav = false
		return

	var viewport: Viewport = get_viewport()
	var _before: Control = null
	if viewport != null:
		_before = viewport.gui_get_focus_owner() as Control

	super._navigate_focus(direction)

func _focus_resume() -> void:
	if _resume_button == null or not _resume_button.is_inside_tree() or not _resume_button.visible:
		_apply_initial_focus()
		return
	call_deferred("_deferred_focus_resume")

func _deferred_focus_resume() -> void:
	if _resume_button != null and _resume_button.is_inside_tree() and _resume_button.visible:
		_resume_button.grab_focus()

func _on_panel_ready() -> void:
	_connect_buttons()
	_localize_labels()

func _connect_buttons() -> void:
	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _save_button != null and not _save_button.pressed.is_connected(_on_save_pressed):
		_save_button.pressed.connect(_on_save_pressed)
	if _load_button != null and not _load_button.pressed.is_connected(_on_load_pressed):
		_load_button.pressed.connect(_on_load_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_dispatch_navigation(U_NavigationActions.close_pause())

func _on_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SETTINGS))

func _on_save_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("save")))
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SAVE_LOAD))

func _on_load_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SAVE_LOAD))

func _on_quit_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_dispatch_navigation(U_NavigationActions.close_pause())

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.title")
	if _resume_button != null:
		_resume_button.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.resume")
	if _settings_button != null:
		_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.settings")
	if _save_button != null:
		_save_button.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.save")
	if _load_button != null:
		_load_button.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.load")
	if _quit_button != null:
		_quit_button.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.quit")

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
