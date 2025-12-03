@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"

## Pause Menu - overlay wired into navigation actions
##
## Buttons dispatch navigation actions instead of calling Scene Manager directly.

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")

const OVERLAY_SETTINGS := StringName("settings_menu_overlay")

@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton

var _last_device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _consume_next_nav: bool = false

func _ready() -> void:
	await super._ready()
	_configure_focus_neighbors()

func _configure_focus_neighbors() -> void:
	var buttons: Array[Control] = []
	if _resume_button != null:
		buttons.append(_resume_button)
	if _settings_button != null:
		buttons.append(_settings_button)
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
	var before: Control = null
	if viewport != null:
		before = viewport.gui_get_focus_owner() as Control

	super._navigate_focus(direction)

	if viewport != null:
		var after: Control = viewport.gui_get_focus_owner() as Control

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

func _connect_buttons() -> void:
	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.close_pause())

func _on_settings_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SETTINGS))

func _on_quit_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _on_back_pressed() -> void:
	_on_resume_pressed()

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)
