@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"

## Pause Menu - overlay wired into navigation actions
##
## Buttons dispatch navigation actions instead of calling Scene Manager directly.

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")

const OVERLAY_SETTINGS := StringName("settings_menu_overlay")
const OVERLAY_INPUT_PROFILE := StringName("input_profile_selector")
const OVERLAY_GAMEPAD_SETTINGS := StringName("gamepad_settings")
const OVERLAY_TOUCHSCREEN_SETTINGS := StringName("touchscreen_settings")
const OVERLAY_INPUT_REBINDING := StringName("input_rebinding")

@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _input_profiles_button: Button = %InputProfilesButton
@onready var _gamepad_settings_button: Button = %GamepadSettingsButton
@onready var _touchscreen_settings_button: Button = %TouchscreenSettingsButton
@onready var _rebind_controls_button: Button = %RebindControlsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	await super._ready()
	_configure_focus_neighbors()

func _configure_focus_neighbors() -> void:
	# Configure vertical focus navigation for pause menu buttons with wrapping
	var buttons: Array[Control] = []
	if _resume_button != null:
		buttons.append(_resume_button)
	if _settings_button != null:
		buttons.append(_settings_button)
	if _input_profiles_button != null:
		buttons.append(_input_profiles_button)
	if _gamepad_settings_button != null:
		buttons.append(_gamepad_settings_button)
	if _touchscreen_settings_button != null:
		buttons.append(_touchscreen_settings_button)
	if _rebind_controls_button != null:
		buttons.append(_rebind_controls_button)
	if _quit_button != null:
		buttons.append(_quit_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(buttons, true)

func _on_store_ready(store_ref: M_StateStore) -> void:
	# Subscribe to navigation state to hide when shell changes away from gameplay
	if store_ref != null:
		store_ref.slice_updated.connect(_on_navigation_changed)

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_navigation_changed):
		store.slice_updated.disconnect(_on_navigation_changed)

func _on_navigation_changed(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("navigation"):
		return

	var store := get_store()
	if store == null:
		return

	var nav_state: Dictionary = store.get_slice(StringName("navigation"))
	var shell: StringName = nav_state.get("shell", StringName())

	# Hide pause menu when transitioning away from gameplay
	if shell != StringName("gameplay"):
		visible = false

func _on_panel_ready() -> void:
	_connect_buttons()

func _connect_buttons() -> void:
	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _input_profiles_button != null and not _input_profiles_button.pressed.is_connected(_on_input_profiles_pressed):
		_input_profiles_button.pressed.connect(_on_input_profiles_pressed)
	if _gamepad_settings_button != null and not _gamepad_settings_button.pressed.is_connected(_on_gamepad_settings_pressed):
		_gamepad_settings_button.pressed.connect(_on_gamepad_settings_pressed)
	if _touchscreen_settings_button != null and not _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed):
		_touchscreen_settings_button.pressed.connect(_on_touchscreen_settings_pressed)
	if _rebind_controls_button != null and not _rebind_controls_button.pressed.is_connected(_on_rebind_controls_pressed):
		_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.close_pause())

func _on_settings_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SETTINGS))

func _on_input_profiles_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_INPUT_PROFILE))

func _on_gamepad_settings_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_GAMEPAD_SETTINGS))

func _on_touchscreen_settings_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_TOUCHSCREEN_SETTINGS))

func _on_rebind_controls_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_INPUT_REBINDING))

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
