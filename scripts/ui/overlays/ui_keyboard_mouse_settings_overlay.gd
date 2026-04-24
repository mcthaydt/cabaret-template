@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_KeyboardMouseSettingsOverlay

const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

const TITLE_KEY := &"settings.keyboard_mouse.title"
const LABEL_MOUSE_SENSITIVITY_KEY := &"settings.keyboard_mouse.label.mouse_sensitivity"
const LABEL_KEYBOARD_LOOK_ENABLED_KEY := &"settings.keyboard_mouse.label.keyboard_look_enabled"
const LABEL_KEYBOARD_LOOK_SPEED_KEY := &"settings.keyboard_mouse.label.keyboard_look_speed"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.keyboard_mouse.button.reset_defaults"
const BUTTON_REBIND_LOOK_KEY := &"settings.keyboard_mouse.button.rebind_look"

const TOOLTIP_MOUSE_SENSITIVITY_KEY := &"settings.keyboard_mouse.tooltip.mouse_sensitivity"
const TOOLTIP_KEYBOARD_LOOK_ENABLED_KEY := &"settings.keyboard_mouse.tooltip.keyboard_look_enabled"
const TOOLTIP_KEYBOARD_LOOK_SPEED_KEY := &"settings.keyboard_mouse.tooltip.keyboard_look_speed"

const DEFAULT_MOUSE_SENSITIVITY: float = 0.6
const MIN_MOUSE_SENSITIVITY: float = 0.1
const MAX_MOUSE_SENSITIVITY: float = 5.0
const DEFAULT_KEYBOARD_LOOK_ENABLED: bool = true
const DEFAULT_KEYBOARD_LOOK_SPEED: float = 2.0

@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _title_label: Label = %HeadingLabel
@onready var _mouse_sensitivity_row: HBoxContainer = %MouseSensitivityRow
@onready var _keyboard_look_enabled_row: HBoxContainer = %KeyboardLookEnabledRow
@onready var _keyboard_look_speed_row: HBoxContainer = %KeyboardLookSpeedRow
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _mouse_sensitivity_label: Label = %MouseSensitivityLabel
@onready var _mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var _mouse_sensitivity_value_label: Label = %MouseSensitivityValue
@onready var _keyboard_look_enabled_label: Label = %KeyboardLookEnabledLabel
@onready var _keyboard_look_speed_label: Label = %KeyboardLookSpeedLabel
@onready var _keyboard_look_enabled_check: CheckButton = %KeyboardLookEnabledCheck
@onready var _keyboard_look_speed_slider: HSlider = %KeyboardLookSpeedSlider
@onready var _keyboard_look_speed_value_label: Label = %KeyboardLookSpeedValue
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _rebind_button: Button = %RebindButton

var _store_unsubscribe: Callable = Callable()
var _updating_from_state: bool = false

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_on_state_changed({}, store.get_state())

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()

func _on_panel_ready() -> void:
	_apply_theme_tokens()
	_configure_focus_neighbors()
	_connect_control_signals()
	_localize_labels()
	_configure_tooltips()
	play_enter_animation()

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG

	var dim_color := config.bg_base
	dim_color.a = 0.5
	background_color = dim_color
	var overlay_background := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_background != null:
		overlay_background.color = dim_color

	if _main_panel != null and config.panel_section != null:
		_main_panel.add_theme_stylebox_override(&"panel", config.panel_section)
	if _main_panel_padding != null:
		_main_panel_padding.add_theme_constant_override(&"margin_left", config.margin_section)
		_main_panel_padding.add_theme_constant_override(&"margin_top", config.margin_section)
		_main_panel_padding.add_theme_constant_override(&"margin_right", config.margin_section)
		_main_panel_padding.add_theme_constant_override(&"margin_bottom", config.margin_section)
	if _main_panel_content != null:
		_main_panel_content.add_theme_constant_override(&"separation", config.separation_default)

	var compact_rows: Array[HBoxContainer] = [
		_mouse_sensitivity_row,
		_keyboard_look_enabled_row,
		_keyboard_look_speed_row,
		_button_row,
	]
	for row in compact_rows:
		if row != null:
			row.add_theme_constant_override(&"separation", config.separation_compact)

	if _title_label != null:
		_title_label.add_theme_font_size_override(&"font_size", config.heading)
	if _mouse_sensitivity_label != null:
		_mouse_sensitivity_label.add_theme_font_size_override(&"font_size", config.section_header)
	if _keyboard_look_enabled_label != null:
		_keyboard_look_enabled_label.add_theme_font_size_override(&"font_size", config.section_header)
	if _keyboard_look_speed_label != null:
		_keyboard_look_speed_label.add_theme_font_size_override(&"font_size", config.section_header)
	if _mouse_sensitivity_value_label != null:
		_mouse_sensitivity_value_label.add_theme_font_size_override(&"font_size", config.body_small)
		_mouse_sensitivity_value_label.add_theme_color_override(&"font_color", config.text_secondary)
	if _keyboard_look_speed_value_label != null:
		_keyboard_look_speed_value_label.add_theme_font_size_override(&"font_size", config.body_small)
		_keyboard_look_speed_value_label.add_theme_color_override(&"font_color", config.text_secondary)
	if _keyboard_look_enabled_check != null:
		_keyboard_look_enabled_check.add_theme_font_size_override(&"font_size", config.section_header)
	if _cancel_button != null:
		_cancel_button.add_theme_font_size_override(&"font_size", config.section_header)
	if _reset_button != null:
		_reset_button.add_theme_font_size_override(&"font_size", config.section_header)
	if _rebind_button != null:
		_rebind_button.add_theme_font_size_override(&"font_size", config.section_header)
	if _apply_button != null:
		_apply_button.add_theme_font_size_override(&"font_size", config.section_header)

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = []
	if _mouse_sensitivity_slider != null:
		vertical_controls.append(_mouse_sensitivity_slider)
	if _keyboard_look_enabled_check != null:
		vertical_controls.append(_keyboard_look_enabled_check)
	if _keyboard_look_speed_slider != null:
		vertical_controls.append(_keyboard_look_speed_slider)

	if not vertical_controls.is_empty():
		U_FocusConfigurator.configure_vertical_focus(vertical_controls, false)

	var buttons: Array[Control] = []
	if _cancel_button != null and _cancel_button.visible:
		buttons.append(_cancel_button)
	if _reset_button != null and _reset_button.visible:
		buttons.append(_reset_button)
	if _rebind_button != null and _rebind_button.visible:
		buttons.append(_rebind_button)
	if _apply_button != null and _apply_button.visible:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		var top_control: Control = _keyboard_look_speed_slider
		if top_control != null and top_control.focus_mode == Control.FOCUS_NONE:
			top_control = _mouse_sensitivity_slider
		if top_control == null:
			top_control = _mouse_sensitivity_slider
		if top_control == null:
			top_control = _keyboard_look_enabled_check
		if top_control != null:
			var down_target: Control = _apply_button if _apply_button != null else buttons[0]
			top_control.focus_neighbor_bottom = top_control.get_path_to(down_target)
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(top_control)
				button.focus_neighbor_bottom = button.get_path_to(top_control)

func _connect_control_signals() -> void:
	if not _mouse_sensitivity_slider.value_changed.is_connected(_on_mouse_sensitivity_changed):
		_mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	if not _keyboard_look_enabled_check.toggled.is_connected(_on_keyboard_look_enabled_toggled):
		_keyboard_look_enabled_check.toggled.connect(_on_keyboard_look_enabled_toggled)
	if not _keyboard_look_speed_slider.value_changed.is_connected(_on_keyboard_look_speed_changed):
		_keyboard_look_speed_slider.value_changed.connect(_on_keyboard_look_speed_changed)
	if not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)
	if not _rebind_button.pressed.is_connected(_on_rebind_pressed):
		_rebind_button.pressed.connect(_on_rebind_pressed)

func _configure_tooltips() -> void:
	if _mouse_sensitivity_slider != null:
		_mouse_sensitivity_slider.tooltip_text = _localize_with_fallback(
			TOOLTIP_MOUSE_SENSITIVITY_KEY,
			"Adjust camera rotation sensitivity for mouse look input."
		)
	if _keyboard_look_enabled_check != null:
		_keyboard_look_enabled_check.tooltip_text = _localize_with_fallback(
			TOOLTIP_KEYBOARD_LOOK_ENABLED_KEY,
			"Allow keyboard keys to rotate the camera."
		)
	if _keyboard_look_speed_slider != null:
		_keyboard_look_speed_slider.tooltip_text = _localize_with_fallback(
			TOOLTIP_KEYBOARD_LOOK_SPEED_KEY,
			"Adjust camera rotation speed for keyboard look input."
		)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var mouse_settings := U_InputSelectors.get_mouse_settings(state)
	_updating_from_state = true
	if not mouse_settings.is_empty():
		_mouse_sensitivity_slider.value = clampf(
			float(mouse_settings.get("sensitivity", DEFAULT_MOUSE_SENSITIVITY)),
			MIN_MOUSE_SENSITIVITY,
			MAX_MOUSE_SENSITIVITY
		)
		_keyboard_look_enabled_check.button_pressed = bool(mouse_settings.get("keyboard_look_enabled", DEFAULT_KEYBOARD_LOOK_ENABLED))
		_keyboard_look_speed_slider.value = clampf(
			float(mouse_settings.get("keyboard_look_speed", DEFAULT_KEYBOARD_LOOK_SPEED)),
			0.1,
			10.0
		)
	_update_slider_label(_mouse_sensitivity_value_label, _mouse_sensitivity_slider.value)
	_update_slider_label(_keyboard_look_speed_value_label, _keyboard_look_speed_slider.value)
	_apply_keyboard_look_enabled_state(_keyboard_look_enabled_check.button_pressed)
	_updating_from_state = false

func _on_mouse_sensitivity_changed(value: float) -> void:
	_update_slider_label(_mouse_sensitivity_value_label, value)
	if not _updating_from_state:
		U_UISoundPlayer.play_slider_tick()

func _on_keyboard_look_enabled_toggled(enabled: bool) -> void:
	_apply_keyboard_look_enabled_state(enabled)
	if not _updating_from_state:
		U_UISoundPlayer.play_slider_tick()

func _on_keyboard_look_speed_changed(value: float) -> void:
	_update_slider_label(_keyboard_look_speed_value_label, value)
	if not _updating_from_state:
		U_UISoundPlayer.play_slider_tick()

func _apply_keyboard_look_enabled_state(enabled: bool) -> void:
	if _keyboard_look_speed_slider != null:
		_keyboard_look_speed_slider.editable = enabled
		_keyboard_look_speed_slider.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		_keyboard_look_speed_slider.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.7, 0.7, 0.7, 1.0)

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		_close_overlay()
		return
	
	var mouse_sensitivity: float = _mouse_sensitivity_slider.value
	var keyboard_look_enabled: bool = _keyboard_look_enabled_check.button_pressed
	var keyboard_look_speed: float = _keyboard_look_speed_slider.value
	store.dispatch(U_InputActions.update_mouse_sensitivity(mouse_sensitivity))
	store.dispatch(U_InputActions.set_keyboard_look_enabled(keyboard_look_enabled))
	store.dispatch(U_InputActions.set_keyboard_look_speed(keyboard_look_speed))
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_mouse_sensitivity_slider.value = DEFAULT_MOUSE_SENSITIVITY
	_update_slider_label(_mouse_sensitivity_value_label, _mouse_sensitivity_slider.value)
	_keyboard_look_enabled_check.button_pressed = DEFAULT_KEYBOARD_LOOK_ENABLED
	_keyboard_look_speed_slider.value = DEFAULT_KEYBOARD_LOOK_SPEED
	_update_slider_label(_keyboard_look_speed_value_label, _keyboard_look_speed_slider.value)
	_apply_keyboard_look_enabled_state(DEFAULT_KEYBOARD_LOOK_ENABLED)

	var store := get_store()
	if store != null:
		store.dispatch(U_InputActions.update_mouse_sensitivity(DEFAULT_MOUSE_SENSITIVITY))
		store.dispatch(U_InputActions.set_keyboard_look_enabled(DEFAULT_KEYBOARD_LOOK_ENABLED))
		store.dispatch(U_InputActions.set_keyboard_look_speed(DEFAULT_KEYBOARD_LOOK_SPEED))

func _on_rebind_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	if shell == StringName("gameplay") and not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.open_overlay(StringName("input_rebinding")))
		return
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("input_rebinding"), "fade", 2))

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _close_overlay() -> void:
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
		return

	if shell == StringName("main_menu"):
		store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_menu"), "fade", 2))
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	_configure_tooltips()

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = _localize_with_fallback(TITLE_KEY, "Keyboard/Mouse Settings")
	if _mouse_sensitivity_label != null:
		_mouse_sensitivity_label.text = _localize_with_fallback(
			LABEL_MOUSE_SENSITIVITY_KEY,
			"Mouse Sensitivity"
		)
	if _keyboard_look_enabled_label != null:
		_keyboard_look_enabled_label.text = _localize_with_fallback(
			LABEL_KEYBOARD_LOOK_ENABLED_KEY,
			"Enable Keyboard Camera Rotation"
		)
	if _keyboard_look_speed_label != null:
		_keyboard_look_speed_label.text = _localize_with_fallback(
			LABEL_KEYBOARD_LOOK_SPEED_KEY,
			"Keyboard Look Speed"
		)

	if _cancel_button != null:
		_cancel_button.text = _localize_with_fallback(&"common.cancel", "Cancel")
	if _reset_button != null:
		_reset_button.text = _localize_with_fallback(BUTTON_RESET_DEFAULTS_KEY, "Reset to Defaults")
	if _rebind_button != null:
		_rebind_button.text = _localize_with_fallback(BUTTON_REBIND_LOOK_KEY, "Rebind Look Keys")
	if _apply_button != null:
		_apply_button.text = _localize_with_fallback(&"common.apply", "Apply")

func _localize_with_fallback(key: StringName, fallback: String) -> String:
	var localized: String = U_LOCALIZATION_UTILS.localize(key)
	if localized == String(key):
		return fallback
	return localized

func _update_slider_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%.2f" % value
