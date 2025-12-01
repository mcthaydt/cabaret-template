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

var _last_device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _consume_next_nav: bool = false

func _ready() -> void:
	print("[PauseMenu] DIAGNOSTIC: _ready called")
	await super._ready()
	print("[PauseMenu] DIAGNOSTIC: super._ready() completed")
	_configure_focus_neighbors()

func _configure_focus_neighbors() -> void:
	var buttons: Array[Control] = []
	if _resume_button != null:
		buttons.append(_resume_button)
	if _settings_button != null:
		buttons.append(_settings_button)
	if _input_profiles_button != null:
		buttons.append(_input_profiles_button)
	if _gamepad_settings_button != null and _gamepad_settings_button.visible:
		buttons.append(_gamepad_settings_button)
	if _touchscreen_settings_button != null and _touchscreen_settings_button.visible:
		buttons.append(_touchscreen_settings_button)
	if _rebind_controls_button != null and _rebind_controls_button.visible:
		buttons.append(_rebind_controls_button)
	if _quit_button != null:
		buttons.append(_quit_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(buttons, true)

func _on_store_ready(store_ref: M_StateStore) -> void:
	print("[PauseMenu] DIAGNOSTIC: _on_store_ready called")
	if store_ref != null:
		store_ref.slice_updated.connect(_on_slice_updated)
		print("[PauseMenu] DIAGNOSTIC: Calling _update_settings_visibility from _on_store_ready")
		_update_settings_visibility(store_ref.get_state())

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return

	print("[PauseMenu] DIAGNOSTIC: _on_slice_updated called, slice_name: ", slice_name)

	if slice_name == StringName("navigation"):
		var nav_state: Dictionary = store.get_slice(StringName("navigation"))
		var shell: StringName = nav_state.get("shell", StringName())
		if shell != StringName("gameplay"):
			visible = false

	print("[PauseMenu] DIAGNOSTIC: Calling _update_settings_visibility from _on_slice_updated")
	_update_settings_visibility(store.get_state())

func _update_settings_visibility(state: Dictionary) -> void:
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var is_gamepad: bool = device_type == M_InputDeviceManager.DeviceType.GAMEPAD
	var is_touchscreen: bool = device_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN

	print("[PauseMenu] DIAGNOSTIC: _update_settings_visibility called")
	print("  - device_type: ", device_type)
	print("  - is_gamepad: ", is_gamepad)
	print("  - is_touchscreen: ", is_touchscreen)

	if _gamepad_settings_button != null:
		_gamepad_settings_button.visible = is_gamepad
		print("[PauseMenu] DIAGNOSTIC: Gamepad button visible = ", is_gamepad)
	if _touchscreen_settings_button != null:
		_touchscreen_settings_button.visible = is_touchscreen
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button visible = ", is_touchscreen)
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button disabled = ", _touchscreen_settings_button.disabled)
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button mouse_filter = ", _touchscreen_settings_button.mouse_filter)
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button is_inside_tree = ", _touchscreen_settings_button.is_inside_tree())
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button is_visible_in_tree = ", _touchscreen_settings_button.is_visible_in_tree())
		print("[PauseMenu] DIAGNOSTIC: Signal connected = ", _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed))
	if _rebind_controls_button != null:
		_rebind_controls_button.visible = not is_touchscreen
		print("[PauseMenu] DIAGNOSTIC: Rebind button visible = ", not is_touchscreen)

	var previous_type: int = _last_device_type
	_last_device_type = device_type

	# CRITICAL FIX: Reconfigure focus neighbors AFTER visibility changes
	# to ensure the focus chain includes/excludes the right buttons
	call_deferred("_configure_focus_neighbors")

	if is_gamepad and previous_type != M_InputDeviceManager.DeviceType.GAMEPAD:
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
	print("[PauseMenu] DIAGNOSTIC: _on_panel_ready called")
	print("[PauseMenu] DIAGNOSTIC: _touchscreen_settings_button null check: ", _touchscreen_settings_button == null)
	_connect_buttons()

func _connect_buttons() -> void:
	print("[PauseMenu] DIAGNOSTIC: _connect_buttons called")

	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
		print("[PauseMenu] DIAGNOSTIC: Connected resume button")
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
		print("[PauseMenu] DIAGNOSTIC: Connected settings button")
	if _input_profiles_button != null and not _input_profiles_button.pressed.is_connected(_on_input_profiles_pressed):
		_input_profiles_button.pressed.connect(_on_input_profiles_pressed)
		print("[PauseMenu] DIAGNOSTIC: Connected input profiles button")
	if _gamepad_settings_button != null and not _gamepad_settings_button.pressed.is_connected(_on_gamepad_settings_pressed):
		_gamepad_settings_button.pressed.connect(_on_gamepad_settings_pressed)
		print("[PauseMenu] DIAGNOSTIC: Connected gamepad settings button")
	if _touchscreen_settings_button != null and not _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed):
		_touchscreen_settings_button.pressed.connect(_on_touchscreen_settings_pressed)
		# DIAGNOSTIC: Add gui_input listener to see if ANY input reaches the button
		if not _touchscreen_settings_button.gui_input.is_connected(_on_touchscreen_button_gui_input):
			_touchscreen_settings_button.gui_input.connect(_on_touchscreen_button_gui_input)
		print("[PauseMenu] DIAGNOSTIC: Connected touchscreen settings button")
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button state:")
		print("  - visible: ", _touchscreen_settings_button.visible)
		print("  - disabled: ", _touchscreen_settings_button.disabled)
		print("  - mouse_filter: ", _touchscreen_settings_button.mouse_filter)
	else:
		print("[PauseMenu] DIAGNOSTIC: Touchscreen button is null or already connected")
		if _touchscreen_settings_button == null:
			print("[PauseMenu] DIAGNOSTIC: _touchscreen_settings_button is NULL!")
		elif _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed):
			print("[PauseMenu] DIAGNOSTIC: Signal already connected")

	if _rebind_controls_button != null and not _rebind_controls_button.pressed.is_connected(_on_rebind_controls_pressed):
		_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
		print("[PauseMenu] DIAGNOSTIC: Connected rebind controls button")
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)
		print("[PauseMenu] DIAGNOSTIC: Connected quit button")

func _on_resume_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.close_pause())

func _on_settings_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SETTINGS))

func _on_input_profiles_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_INPUT_PROFILE))

func _on_gamepad_settings_pressed() -> void:
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_GAMEPAD_SETTINGS))

func _on_touchscreen_button_gui_input(event: InputEvent) -> void:
	print("[PauseMenu] DIAGNOSTIC: gui_input received on touchscreen button!")
	print("  - event type: ", event.get_class())
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		print("  - touch pressed: ", touch.pressed)
		print("  - touch position: ", touch.position)

func _on_touchscreen_settings_pressed() -> void:
	print("[PauseMenu] DIAGNOSTIC: ========================================")
	print("[PauseMenu] DIAGNOSTIC: TOUCHSCREEN SETTINGS BUTTON PRESSED!!!")
	print("[PauseMenu] DIAGNOSTIC: ========================================")
	print("[PauseMenu] DIAGNOSTIC: Dispatching open_overlay action for: ", OVERLAY_TOUCHSCREEN_SETTINGS)
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
