@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_SettingsMenu

## Settings Menu UI Controller
##
## Runs as either an overlay (pause → settings) or as embedded UI in the main
## menu. Uses navigation actions for all flows (overlay management and scene transitions).


@onready var _back_button: Button = %BackButton
@onready var _input_profiles_button: Button = %InputProfilesButton
@onready var _gamepad_settings_button: Button = %GamepadSettingsButton
@onready var _touchscreen_settings_button: Button = %TouchscreenSettingsButton
@onready var _vfx_settings_button: Button = %VFXSettingsButton
@onready var _display_settings_button: Button = %DisplaySettingsButton
@onready var _audio_settings_button: Button = %AudioSettingsButton
@onready var _rebind_controls_button: Button = %RebindControlsButton

const SETTINGS_OVERLAY_ID := StringName("settings_menu_overlay")
const OVERLAY_INPUT_PROFILE := StringName("input_profile_selector")
const OVERLAY_GAMEPAD_SETTINGS := StringName("gamepad_settings")
const OVERLAY_TOUCHSCREEN_SETTINGS := StringName("touchscreen_settings")
const OVERLAY_VFX_SETTINGS := StringName("vfx_settings")
const OVERLAY_DISPLAY_SETTINGS := StringName("display_settings")
const OVERLAY_AUDIO_SETTINGS := StringName("audio_settings")
const OVERLAY_INPUT_REBINDING := StringName("input_rebinding")

var _last_device_type: int = -1
var _consume_next_nav: bool = false

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
	if _vfx_settings_button != null and not _vfx_settings_button.pressed.is_connected(_on_vfx_settings_pressed):
		_vfx_settings_button.pressed.connect(_on_vfx_settings_pressed)
	if _display_settings_button != null and not _display_settings_button.pressed.is_connected(_on_display_settings_pressed):
		_display_settings_button.pressed.connect(_on_display_settings_pressed)
	if _audio_settings_button != null and not _audio_settings_button.pressed.is_connected(_on_audio_settings_pressed):
		_audio_settings_button.pressed.connect(_on_audio_settings_pressed)
	if _rebind_controls_button != null and not _rebind_controls_button.pressed.is_connected(_on_rebind_controls_pressed):
		_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
	_configure_focus_neighbors()
	_update_back_button_label()
	var store := get_store()
	if store != null:
		_update_button_visibility(store.get_state())

func _on_slice_updated(__slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return
	_update_button_visibility(store.get_state())

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
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
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_INPUT_PROFILE, StringName("input_profile_selector"))

func _on_gamepad_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_GAMEPAD_SETTINGS, StringName("gamepad_settings"))

func _on_touchscreen_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_TOUCHSCREEN_SETTINGS, StringName("touchscreen_settings"))

func _on_vfx_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_VFX_SETTINGS, StringName("vfx_settings"))

func _on_display_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_DISPLAY_SETTINGS, StringName("display_settings"))

func _on_audio_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_AUDIO_SETTINGS, StringName("audio_settings"))

func _on_rebind_controls_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_INPUT_REBINDING, StringName("input_rebinding"))

func _update_button_visibility(state: Dictionary) -> void:
	var has_gamepad: bool = U_InputSelectors.is_gamepad_connected(state)
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var is_mobile: bool = OS.has_feature("mobile")
	var args: PackedStringArray = OS.get_cmdline_args()
	var is_emulated_mobile: bool = args.has("--emulate-mobile")
	var is_mobile_context: bool = is_mobile or is_emulated_mobile
	var is_gamepad_active: bool = (device_type == M_InputDeviceManager.DeviceType.GAMEPAD)

	if device_type != _last_device_type:
		var previous_type: int = _last_device_type
		_last_device_type = device_type

		var viewport := get_viewport()
		var focused: Control = null
		if viewport != null:
			focused = viewport.gui_get_focus_owner() as Control
		# When switching back to gamepad:
		# - Reset the analog repeater so previous stick state doesn't leak.
		# - Consume the first navigation tick to avoid an immediate skip.
		# - If there is no valid focus owner, re-apply initial focus so the
		#   analog stick has a stable starting target.
		# Only do this when transitioning specifically from TOUCHSCREEN → GAMEPAD.
		if device_type == M_InputDeviceManager.DeviceType.GAMEPAD \
				and previous_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN:
			reset_analog_navigation()
			_consume_next_nav = true
			if focused == null or not is_ancestor_of(focused) or not focused.is_visible_in_tree():
				_apply_initial_focus()

	if _gamepad_settings_button != null:
		# Hide gamepad settings whenever the active device is touchscreen,
		# even if a gamepad is connected in the background.
		_gamepad_settings_button.visible = has_gamepad and device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN
	if _touchscreen_settings_button != null:
		# Only show touchscreen settings when in a mobile context AND
		# the active device is not a gamepad. This keeps touch settings
		# out of the way when the user is actively using a gamepad, even
		# on mobile / emulated-mobile builds.
		_touchscreen_settings_button.visible = is_mobile_context and not is_gamepad_active
	if _rebind_controls_button != null:
		# Rebind Controls is not relevant in pure touchscreen usage; hide it
		# whenever the active device is touchscreen.
		_rebind_controls_button.visible = device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN

	_configure_focus_neighbors()

func _configure_focus_neighbors() -> void:
	var buttons: Array[Control] = []
	if _input_profiles_button != null and _input_profiles_button.visible:
		buttons.append(_input_profiles_button)
	if _gamepad_settings_button != null and _gamepad_settings_button.visible:
		buttons.append(_gamepad_settings_button)
	if _touchscreen_settings_button != null and _touchscreen_settings_button.visible:
		buttons.append(_touchscreen_settings_button)
	if _vfx_settings_button != null and _vfx_settings_button.visible:
		buttons.append(_vfx_settings_button)
	if _display_settings_button != null and _display_settings_button.visible:
		buttons.append(_display_settings_button)
	if _audio_settings_button != null and _audio_settings_button.visible:
		buttons.append(_audio_settings_button)
	if _rebind_controls_button != null and _rebind_controls_button.visible:
		buttons.append(_rebind_controls_button)
	if _back_button != null and _back_button.visible:
		buttons.append(_back_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_vertical_focus(buttons, true)

func _navigate_focus(direction: StringName) -> void:
	if _consume_next_nav:
		_consume_next_nav = false
		return
	super._navigate_focus(direction)

func _open_settings_target(overlay_id: StringName, scene_id: StringName) -> void:
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	# Gameplay overlay flow: open as overlay above settings overlay.
	if shell == StringName("gameplay") and not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.open_overlay(overlay_id))
		return

	# Menu flow (main menu/settings scene): navigate to standalone UI scene via Redux action.
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(scene_id, "fade", 2))

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
