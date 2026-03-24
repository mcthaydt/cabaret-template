@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_SettingsMenu

## Settings Menu UI Controller
##
## Runs as either an overlay (pause → settings) or as embedded UI in the main
## menu. Uses navigation actions for all flows (overlay management and scene transitions).


const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/resources/ui/rs_ui_theme_config.gd")

@onready var _title_label: Label = %TitleLabel
@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _buttons_vbox: VBoxContainer = %ButtonsVBox
@onready var _back_button: Button = %BackButton
@onready var _input_profiles_button: Button = %InputProfilesButton
@onready var _gamepad_settings_button: Button = %GamepadSettingsButton
@onready var _keyboard_mouse_settings_button: Button = %KeyboardMouseSettingsButton
@onready var _touchscreen_settings_button: Button = %TouchscreenSettingsButton
@onready var _vfx_settings_button: Button = %VFXSettingsButton
@onready var _display_settings_button: Button = %DisplaySettingsButton
@onready var _audio_settings_button: Button = %AudioSettingsButton
@onready var _language_settings_button: Button = %LanguageSettingsButton
@onready var _rebind_controls_button: Button = %RebindControlsButton

@export var emulate_mobile_override: bool = false

const SETTINGS_OVERLAY_ID := StringName("settings_menu_overlay")
const OVERLAY_INPUT_PROFILE := StringName("input_profile_selector")
const OVERLAY_GAMEPAD_SETTINGS := StringName("gamepad_settings")
const OVERLAY_KEYBOARD_MOUSE_SETTINGS := StringName("keyboard_mouse_settings")
const OVERLAY_TOUCHSCREEN_SETTINGS := StringName("touchscreen_settings")
const OVERLAY_VFX_SETTINGS := StringName("vfx_settings")
const OVERLAY_DISPLAY_SETTINGS := StringName("display_settings")
const OVERLAY_AUDIO_SETTINGS := StringName("audio_settings")
const OVERLAY_INPUT_REBINDING := StringName("input_rebinding")
const OVERLAY_LOCALIZATION_SETTINGS := StringName("localization_settings")
const SETTINGS_SCENE_ID := StringName("settings_menu")

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
	_apply_theme_tokens()
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _input_profiles_button != null and not _input_profiles_button.pressed.is_connected(_on_input_profiles_pressed):
		_input_profiles_button.pressed.connect(_on_input_profiles_pressed)
	if _gamepad_settings_button != null and not _gamepad_settings_button.pressed.is_connected(_on_gamepad_settings_pressed):
		_gamepad_settings_button.pressed.connect(_on_gamepad_settings_pressed)
	if _keyboard_mouse_settings_button != null and not _keyboard_mouse_settings_button.pressed.is_connected(_on_keyboard_mouse_settings_pressed):
		_keyboard_mouse_settings_button.pressed.connect(_on_keyboard_mouse_settings_pressed)
	if _touchscreen_settings_button != null and not _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed):
		_touchscreen_settings_button.pressed.connect(_on_touchscreen_settings_pressed)
	if _vfx_settings_button != null and not _vfx_settings_button.pressed.is_connected(_on_vfx_settings_pressed):
		_vfx_settings_button.pressed.connect(_on_vfx_settings_pressed)
	if _display_settings_button != null and not _display_settings_button.pressed.is_connected(_on_display_settings_pressed):
		_display_settings_button.pressed.connect(_on_display_settings_pressed)
	if _audio_settings_button != null and not _audio_settings_button.pressed.is_connected(_on_audio_settings_pressed):
		_audio_settings_button.pressed.connect(_on_audio_settings_pressed)
	if _language_settings_button != null and not _language_settings_button.pressed.is_connected(_on_language_settings_pressed):
		_language_settings_button.pressed.connect(_on_language_settings_pressed)
	if _rebind_controls_button != null and not _rebind_controls_button.pressed.is_connected(_on_rebind_controls_pressed):
		_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
	_configure_focus_neighbors()
	_update_back_button_label()
	_localize_labels()
	var store := get_store()
	if store != null:
		_update_button_visibility(store.get_state())
	play_enter_animation()

func _on_slice_updated(__slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return
	_update_button_visibility(store.get_state())
	_update_back_button_label()
	_refresh_background_dim()

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

func _on_keyboard_mouse_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_KEYBOARD_MOUSE_SETTINGS, StringName("keyboard_mouse_settings"))

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

func _on_language_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_LOCALIZATION_SETTINGS, StringName("localization_settings"))

func _on_rebind_controls_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_open_settings_target(OVERLAY_INPUT_REBINDING, StringName("input_rebinding"))

func _update_button_visibility(state: Dictionary) -> void:
	var has_gamepad: bool = U_InputSelectors.is_gamepad_connected(state)
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var is_mobile_context: bool = _is_mobile_context()
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
	if _keyboard_mouse_settings_button != null:
		# Keyboard/Mouse settings are desktop-only and should never appear
		# in mobile contexts, even when a gamepad is connected.
		_keyboard_mouse_settings_button.visible = not is_mobile_context
	if _rebind_controls_button != null:
		# Rebind Controls is not relevant in pure touchscreen usage; hide it
		# whenever the active device is touchscreen.
		_rebind_controls_button.visible = device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN

	_configure_focus_neighbors()

func _is_mobile_context() -> bool:
	if emulate_mobile_override:
		return true
	if OS.has_feature("mobile"):
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--emulate-mobile")

func _configure_focus_neighbors() -> void:
	var buttons: Array[Control] = []
	if _input_profiles_button != null and _input_profiles_button.visible:
		buttons.append(_input_profiles_button)
	if _gamepad_settings_button != null and _gamepad_settings_button.visible:
		buttons.append(_gamepad_settings_button)
	if _keyboard_mouse_settings_button != null and _keyboard_mouse_settings_button.visible:
		buttons.append(_keyboard_mouse_settings_button)
	if _touchscreen_settings_button != null and _touchscreen_settings_button.visible:
		buttons.append(_touchscreen_settings_button)
	if _vfx_settings_button != null and _vfx_settings_button.visible:
		buttons.append(_vfx_settings_button)
	if _display_settings_button != null and _display_settings_button.visible:
		buttons.append(_display_settings_button)
	if _audio_settings_button != null and _audio_settings_button.visible:
		buttons.append(_audio_settings_button)
	if _language_settings_button != null and _language_settings_button.visible:
		buttons.append(_language_settings_button)
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
	_back_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.back") if is_overlay else U_LOCALIZATION_UTILS.localize(&"menu.settings.back_to_main")

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if config_resource is RS_UI_THEME_CONFIG:
		var config := config_resource as RS_UI_THEME_CONFIG
		if _main_panel != null and config.panel_section != null:
			_main_panel.add_theme_stylebox_override(&"panel", config.panel_section)
		if _main_panel_padding != null:
			_main_panel_padding.add_theme_constant_override(&"margin_left", config.margin_section)
			_main_panel_padding.add_theme_constant_override(&"margin_top", config.margin_section)
			_main_panel_padding.add_theme_constant_override(&"margin_right", config.margin_section)
			_main_panel_padding.add_theme_constant_override(&"margin_bottom", config.margin_section)
		if _main_panel_content != null:
			_main_panel_content.add_theme_constant_override(&"separation", config.separation_default)
		if _buttons_vbox != null:
			_buttons_vbox.add_theme_constant_override(&"separation", config.separation_default)
		if _title_label != null:
			_title_label.add_theme_font_size_override(&"font_size", config.heading)

	_refresh_background_dim()

func _refresh_background_dim() -> void:
	var base_color := background_color
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if config_resource is RS_UI_THEME_CONFIG:
		base_color = (config_resource as RS_UI_THEME_CONFIG).bg_base
	if _is_overlay_context():
		base_color.a = 0.7
	elif _is_standalone_settings_scene():
		base_color.a = 1.0
	else:
		base_color.a = 0.0
	background_color = base_color

	var overlay_background := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_background != null:
		overlay_background.color = base_color

func _is_overlay_context() -> bool:
	var store := get_store()
	if store == null:
		return false
	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	return U_NavigationSelectors.get_top_overlay_id(nav_slice) == SETTINGS_OVERLAY_ID

func _is_standalone_settings_scene() -> bool:
	var store := get_store()
	if store == null:
		return false
	var scene_slice: Dictionary = store.get_state().get("scene", {})
	var current_scene_id: StringName = scene_slice.get("current_scene_id", StringName(""))
	return current_scene_id == SETTINGS_SCENE_ID

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.title")
	if _input_profiles_button != null:
		_input_profiles_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.input_profiles")
	if _gamepad_settings_button != null:
		_gamepad_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.gamepad")
	if _keyboard_mouse_settings_button != null:
		_keyboard_mouse_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.keyboard_mouse")
	if _touchscreen_settings_button != null:
		_touchscreen_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.touchscreen")
	if _vfx_settings_button != null:
		_vfx_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.vfx")
	if _display_settings_button != null:
		_display_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.display")
	if _audio_settings_button != null:
		_audio_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.audio")
	if _language_settings_button != null:
		_language_settings_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.language")
	if _rebind_controls_button != null:
		_rebind_controls_button.text = U_LOCALIZATION_UTILS.localize(&"menu.settings.rebind")
	_update_back_button_label()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
