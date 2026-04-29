@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_TouchscreenSettingsOverlay

const VirtualJoystickScene := preload("res://scenes/core/ui/widgets/ui_virtual_joystick.tscn")
const VirtualButtonScene := preload("res://scenes/core/ui/widgets/ui_virtual_button.tscn")
const I_INPUT_PROFILE_MANAGER := preload("res://scripts/core/interfaces/i_input_profile_manager.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

const TITLE_KEY := &"settings.touchscreen.title"
const LABEL_JOYSTICK_SIZE_KEY := &"settings.touchscreen.label.joystick_size"
const LABEL_BUTTON_SIZE_KEY := &"settings.touchscreen.label.button_size"
const LABEL_JOYSTICK_OPACITY_KEY := &"settings.touchscreen.label.joystick_opacity"
const LABEL_BUTTON_OPACITY_KEY := &"settings.touchscreen.label.button_opacity"
const LABEL_JOYSTICK_DEADZONE_KEY := &"settings.touchscreen.label.joystick_deadzone"
const LABEL_LOOK_SENSITIVITY_KEY := &"settings.touchscreen.label.look_sensitivity"
const BUTTON_EDIT_LAYOUT_KEY := &"settings.touchscreen.button.edit_layout"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.touchscreen.button.reset_defaults"

const TOOLTIP_JOYSTICK_SIZE_KEY := &"settings.touchscreen.tooltip.joystick_size"
const TOOLTIP_BUTTON_SIZE_KEY := &"settings.touchscreen.tooltip.button_size"
const TOOLTIP_JOYSTICK_OPACITY_KEY := &"settings.touchscreen.tooltip.joystick_opacity"
const TOOLTIP_BUTTON_OPACITY_KEY := &"settings.touchscreen.tooltip.button_opacity"
const TOOLTIP_JOYSTICK_DEADZONE_KEY := &"settings.touchscreen.tooltip.joystick_deadzone"
const TOOLTIP_LOOK_SENSITIVITY_KEY := &"settings.touchscreen.tooltip.look_sensitivity"
const TOOLTIP_PREVIEW_KEY := &"settings.touchscreen.tooltip.preview"
const TOOLTIP_EDIT_LAYOUT_KEY := &"settings.touchscreen.tooltip.edit_layout"

@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _preview_panel: PanelContainer = %PreviewPanel
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _title_label: Label = %HeadingLabel
@onready var _joystick_size_row: HBoxContainer = %JoystickSizeRow
@onready var _button_size_row: HBoxContainer = %ButtonSizeRow
@onready var _joystick_opacity_row: HBoxContainer = %JoystickOpacityRow
@onready var _button_opacity_row: HBoxContainer = %ButtonOpacityRow
@onready var _joystick_deadzone_row: HBoxContainer = %JoystickDeadzoneRow
@onready var _look_sensitivity_row: HBoxContainer = %LookSensitivityRow
@onready var _joystick_size_text_label: Label = %JoystickSizeLabel
@onready var _button_size_text_label: Label = %ButtonSizeLabel
@onready var _joystick_opacity_text_label: Label = %JoystickOpacityLabel
@onready var _button_opacity_text_label: Label = %ButtonOpacityLabel
@onready var _joystick_deadzone_text_label: Label = %JoystickDeadzoneLabel
@onready var _look_sensitivity_text_label: Label = %LookSensitivityLabel

@onready var _joystick_size_slider: HSlider = %JoystickSizeSlider
@onready var _button_size_slider: HSlider = %ButtonSizeSlider
@onready var _joystick_opacity_slider: HSlider = %JoystickOpacitySlider
@onready var _button_opacity_slider: HSlider = %ButtonOpacitySlider
@onready var _joystick_deadzone_slider: HSlider = %JoystickDeadzoneSlider
@onready var _look_sensitivity_slider: HSlider = %LookSensitivitySlider

@onready var _joystick_size_label: Label = %JoystickSizeValue
@onready var _button_size_label: Label = %ButtonSizeValue
@onready var _joystick_opacity_label: Label = %JoystickOpacityValue
@onready var _button_opacity_label: Label = %ButtonOpacityValue
@onready var _joystick_deadzone_label: Label = %JoystickDeadzoneValue
@onready var _look_sensitivity_label: Label = %LookSensitivityValue

@onready var _preview_container: Control = %PreviewContainer
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _edit_layout_button: Button = %EditLayoutButton

@export var input_profile_manager: Node = null

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

var _store_unsubscribe: Callable = Callable()
var _profile_manager: Node = null
var _preview_joystick: Control = null
var _preview_buttons: Array[Control] = []
var _defaults: RS_TouchscreenSettings = preload("res://resources/core/input/touchscreen_settings/cfg_default_touchscreen_settings.tres")
var _preview_builder := U_TouchscreenPreviewHelper.new()
var _updating_from_state: bool = false
var _has_local_edits: bool = false
var _override_log_count: int = 0
var _builder: RefCounted = null

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_on_state_changed({}, store.get_state())

func _on_panel_ready() -> void:
	_setup_builder()
	_apply_theme_tokens()
	_profile_manager = _resolve_input_profile_manager()

	_configure_focus_neighbors()
	_build_preview()
	_apply_preview_size_limits()
	call_deferred("_refresh_preview_size_limits_deferred")
	_connect_signals()
	_localize_labels()
	_configure_tooltips()
	_update_preview_from_sliders()
	_update_edit_layout_visibility()
	play_enter_animation()

func _setup_builder() -> void:
	_builder = U_SETTINGS_TAB_BUILDER.new(self)
	_builder.bind_overlay_background(0.5, get_node_or_null("OverlayBackground") as ColorRect)
	_builder.bind_panel(_main_panel, _main_panel_content, _main_panel_padding)
	_builder.bind_panel(_preview_panel)
	_builder.bind_heading(_title_label, TITLE_KEY)
	_builder.bind_row(_joystick_size_row, true)
	_builder.bind_row(_button_size_row, true)
	_builder.bind_row(_joystick_opacity_row, true)
	_builder.bind_row(_button_opacity_row, true)
	_builder.bind_row(_joystick_deadzone_row, true)
	_builder.bind_row(_look_sensitivity_row, true)
	_builder.bind_row(_button_row, true)
	_builder.bind_section_header(_joystick_size_text_label, LABEL_JOYSTICK_SIZE_KEY)
	_builder.bind_section_header(_button_size_text_label, LABEL_BUTTON_SIZE_KEY)
	_builder.bind_section_header(_joystick_opacity_text_label, LABEL_JOYSTICK_OPACITY_KEY)
	_builder.bind_section_header(_button_opacity_text_label, LABEL_BUTTON_OPACITY_KEY)
	_builder.bind_section_header(_joystick_deadzone_text_label, LABEL_JOYSTICK_DEADZONE_KEY)
	_builder.bind_section_header(_look_sensitivity_text_label, LABEL_LOOK_SENSITIVITY_KEY)
	_builder.bind_value_label(_joystick_size_label, &"")
	_builder.bind_value_label(_button_size_label, &"")
	_builder.bind_value_label(_joystick_opacity_label, &"")
	_builder.bind_value_label(_button_opacity_label, &"")
	_builder.bind_value_label(_joystick_deadzone_label, &"")
	_builder.bind_value_label(_look_sensitivity_label, &"")
	_builder.bind_action_button(_cancel_button, &"common.cancel", _on_cancel_pressed, "Cancel")
	_builder.bind_action_button(_reset_button, BUTTON_RESET_DEFAULTS_KEY, _on_reset_pressed, "Reset to Defaults")
	_builder.bind_action_button(_edit_layout_button, BUTTON_EDIT_LAYOUT_KEY, _on_edit_layout_pressed, "Edit Layout")
	_builder.bind_action_button(_apply_button, &"common.apply", _on_apply_pressed, "Apply")
	_builder.build()

func _refresh_preview_size_limits_deferred() -> void:
	_apply_preview_size_limits()
	_update_preview_from_sliders()

func _apply_theme_tokens() -> void:
	if _builder != null:
		_builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)

func _resolve_input_profile_manager() -> Node:
	if input_profile_manager != null and is_instance_valid(input_profile_manager):
		return input_profile_manager

	var manager := U_ServiceLocator.try_get_service(INPUT_PROFILE_MANAGER_SERVICE)
	if manager != null:
		return manager

	return null

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()

func _build_preview() -> void:
	if _preview_container == null:
		return

	var joystick_out: Array = []
	var buttons_out: Array = []
	_preview_builder.build_preview(
		_preview_container,
		VirtualJoystickScene,
		VirtualButtonScene,
		joystick_out,
		buttons_out
	)

	_preview_joystick = null
	if not joystick_out.is_empty():
		var first_joystick: Control = joystick_out[0] as Control
		if first_joystick != null:
			_preview_joystick = first_joystick

	_preview_buttons.clear()
	for entry in buttons_out:
		if entry is Control:
			_preview_buttons.append(entry)

func _apply_preview_size_limits() -> void:
	if _preview_container == null:
		return
	if _joystick_size_slider == null or _button_size_slider == null:
		return
	var max_scales: Dictionary = _preview_builder.get_max_preview_scales(
		_preview_container,
		_preview_joystick,
		_preview_buttons
	)
	var joystick_max: float = max(
		float(max_scales.get("joystick", _joystick_size_slider.max_value)),
		_joystick_size_slider.min_value
	)
	var button_max: float = max(
		float(max_scales.get("button", _button_size_slider.max_value)),
		_button_size_slider.min_value
	)

	_joystick_size_slider.max_value = joystick_max
	_button_size_slider.max_value = button_max
	_joystick_size_slider.set_value_no_signal(min(_joystick_size_slider.value, joystick_max))
	_button_size_slider.set_value_no_signal(min(_button_size_slider.value, button_max))

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = []
	if _joystick_size_slider != null:
		vertical_controls.append(_joystick_size_slider)
	if _button_size_slider != null:
		vertical_controls.append(_button_size_slider)
	if _joystick_opacity_slider != null:
		vertical_controls.append(_joystick_opacity_slider)
	if _button_opacity_slider != null:
		vertical_controls.append(_button_opacity_slider)
	if _joystick_deadzone_slider != null:
		vertical_controls.append(_joystick_deadzone_slider)
	if _look_sensitivity_slider != null:
		vertical_controls.append(_look_sensitivity_slider)

	if not vertical_controls.is_empty():
		U_FocusConfigurator.configure_vertical_focus(vertical_controls, false)

	var buttons: Array[Control] = []
	if _cancel_button != null and _cancel_button.visible:
		buttons.append(_cancel_button)
	if _reset_button != null and _reset_button.visible:
		buttons.append(_reset_button)
	if _edit_layout_button != null and _edit_layout_button.visible:
		buttons.append(_edit_layout_button)
	if _apply_button != null and _apply_button.visible:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		var top_control: Control = _look_sensitivity_slider
		if top_control == null:
			top_control = _joystick_deadzone_slider
		if top_control != null:
			# Use Apply as the primary down target; fall back to first button if missing.
			var down_target: Control = _apply_button if _apply_button != null else buttons[0]
			top_control.focus_neighbor_bottom = top_control.get_path_to(down_target)
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(top_control)
				button.focus_neighbor_bottom = button.get_path_to(top_control)

func _connect_signals() -> void:
	_joystick_size_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("virtual_joystick_size", value)
		_update_slider_label(_joystick_size_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
		_update_preview_from_sliders()
	)
	_button_size_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("button_size", value)
		_update_slider_label(_button_size_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
		_update_preview_from_sliders()
	)
	_joystick_opacity_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("virtual_joystick_opacity", value)
		_update_slider_label(_joystick_opacity_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
		_update_preview_from_sliders()
	)
	_button_opacity_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("button_opacity", value)
		_update_slider_label(_button_opacity_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
		_update_preview_from_sliders()
	)
	_joystick_deadzone_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("joystick_deadzone", value)
		_update_slider_label(_joystick_deadzone_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
		_update_preview_from_sliders()
	)
	_look_sensitivity_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("look_drag_sensitivity", value)
		_update_slider_label(_look_sensitivity_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
	)

func _configure_tooltips() -> void:
	if _joystick_size_slider != null:
		_joystick_size_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_JOYSTICK_SIZE_KEY,
			"Adjust virtual joystick size."
		)
	if _button_size_slider != null:
		_button_size_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_BUTTON_SIZE_KEY,
			"Adjust touch button size."
		)
	if _joystick_opacity_slider != null:
		_joystick_opacity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_JOYSTICK_OPACITY_KEY,
			"Adjust virtual joystick opacity."
		)
	if _button_opacity_slider != null:
		_button_opacity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_BUTTON_OPACITY_KEY,
			"Adjust touch button opacity."
		)
	if _joystick_deadzone_slider != null:
		_joystick_deadzone_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_JOYSTICK_DEADZONE_KEY,
			"Adjust joystick deadzone before input registers."
		)
	if _look_sensitivity_slider != null:
		_look_sensitivity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_LOOK_SENSITIVITY_KEY,
			"Adjust drag sensitivity for touchscreen camera look."
		)
	if _preview_container != null:
		_preview_container.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_PREVIEW_KEY,
			"Preview current touchscreen control settings."
		)
	if _edit_layout_button != null:
		_edit_layout_button.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_EDIT_LAYOUT_KEY,
			"Open layout editor to reposition controls."
		)

func _update_edit_layout_visibility() -> void:
	if _edit_layout_button == null:
		return

	var store := get_store()
	if store == null:
		_edit_layout_button.visible = true
		_configure_focus_neighbors()
		return

	var nav_state: Dictionary = store.get_slice(StringName("navigation"))
	var shell: StringName = U_NavigationSelectors.get_shell(nav_state)

	# Hide Edit Layout when accessing touchscreen settings from main menu,
	# since no on-screen controls are visible in that context.
	_edit_layout_button.visible = (shell == StringName("gameplay"))
	_configure_focus_neighbors()

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var action_type: StringName = StringName("")
	if _action.has("type"):
		action_type = _action.get("type", StringName(""))

	# Preserve in-progress slider edits when position-only updates arrive (e.g. layout reset).
	if _has_local_edits and action_type == U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS:
		var settings_payload: Dictionary = _action.get("payload", {}).get("settings", {})
		if _is_position_only_settings_update(settings_payload):
			return

	# Skip applying non-settings actions when the user has local edits in progress.
	if _has_local_edits and action_type != StringName("") and action_type != U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS:
		return

	var settings := U_InputSelectors.get_touchscreen_settings(state)
	var overridden_fields: Array[String] = []
	if not settings.is_empty():
		var joystick_size_from_state := float(settings.get("virtual_joystick_size", _joystick_size_slider.value))
		var button_size_from_state := float(settings.get("button_size", _button_size_slider.value))
		var joystick_opacity_from_state := float(settings.get("virtual_joystick_opacity", _joystick_opacity_slider.value))
		var button_opacity_from_state := float(settings.get("button_opacity", _button_opacity_slider.value))
		var joystick_deadzone_from_state := float(settings.get("joystick_deadzone", _joystick_deadzone_slider.value))
		var look_sensitivity_from_state := float(settings.get("look_drag_sensitivity", _look_sensitivity_slider.value))

		if not is_equal_approx(_joystick_size_slider.value, joystick_size_from_state):
			overridden_fields.append("virtual_joystick_size")
		if not is_equal_approx(_button_size_slider.value, button_size_from_state):
			overridden_fields.append("button_size")
		if not is_equal_approx(_joystick_opacity_slider.value, joystick_opacity_from_state):
			overridden_fields.append("virtual_joystick_opacity")
		if not is_equal_approx(_button_opacity_slider.value, button_opacity_from_state):
			overridden_fields.append("button_opacity")
		if not is_equal_approx(_joystick_deadzone_slider.value, joystick_deadzone_from_state):
			overridden_fields.append("joystick_deadzone")
		if not is_equal_approx(_look_sensitivity_slider.value, look_sensitivity_from_state):
			overridden_fields.append("look_drag_sensitivity")

		if not overridden_fields.is_empty() and action_type != U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS and action_type != StringName(""):
			_override_log_count += 1

	_updating_from_state = true
	if not settings.is_empty():
		_joystick_size_slider.value = float(settings.get("virtual_joystick_size", _joystick_size_slider.value))
		_button_size_slider.value = float(settings.get("button_size", _button_size_slider.value))
		_joystick_opacity_slider.value = float(settings.get("virtual_joystick_opacity", _joystick_opacity_slider.value))
		_button_opacity_slider.value = float(settings.get("button_opacity", _button_opacity_slider.value))
		_joystick_deadzone_slider.value = float(settings.get("joystick_deadzone", _joystick_deadzone_slider.value))
		_look_sensitivity_slider.value = float(settings.get("look_drag_sensitivity", _look_sensitivity_slider.value))

	_update_slider_label(_joystick_size_label, _joystick_size_slider.value)
	_update_slider_label(_button_size_label, _button_size_slider.value)
	_update_slider_label(_joystick_opacity_label, _joystick_opacity_slider.value)
	_update_slider_label(_button_opacity_label, _button_opacity_slider.value)
	_update_slider_label(_joystick_deadzone_label, _joystick_deadzone_slider.value)
	_update_slider_label(_look_sensitivity_label, _look_sensitivity_slider.value)

	_updating_from_state = false
	_update_preview_from_sliders()

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		_close_overlay()
		return

	var joystick_size := float(_joystick_size_slider.value)
	var button_size := float(_button_size_slider.value)
	var joystick_opacity := float(_joystick_opacity_slider.value)
	var button_opacity := float(_button_opacity_slider.value)
	var joystick_deadzone := float(_joystick_deadzone_slider.value)
	var look_drag_sensitivity := float(_look_sensitivity_slider.value)

	var settings_updates := {
		"virtual_joystick_size": joystick_size,
		"button_size": button_size,
		"virtual_joystick_opacity": joystick_opacity,
		"button_opacity": button_opacity,
		"joystick_deadzone": joystick_deadzone,
		"look_drag_sensitivity": look_drag_sensitivity,
	}

	store.dispatch(U_InputActions.update_touchscreen_settings(settings_updates))
	_has_local_edits = false
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_joystick_size_slider.value = _defaults.virtual_joystick_size
	_button_size_slider.value = _defaults.button_size
	_joystick_opacity_slider.value = _defaults.virtual_joystick_opacity
	_button_opacity_slider.value = _defaults.button_opacity
	_joystick_deadzone_slider.value = _defaults.joystick_deadzone
	_look_sensitivity_slider.value = _defaults.look_drag_sensitivity

	_update_slider_label(_joystick_size_label, _joystick_size_slider.value)
	_update_slider_label(_button_size_label, _button_size_slider.value)
	_update_slider_label(_joystick_opacity_label, _joystick_opacity_slider.value)
	_update_slider_label(_button_opacity_label, _button_opacity_slider.value)
	_update_slider_label(_joystick_deadzone_label, _joystick_deadzone_slider.value)
	_update_slider_label(_look_sensitivity_label, _look_sensitivity_slider.value)

	_update_preview_from_sliders()

	var typed_manager := _profile_manager as I_INPUT_PROFILE_MANAGER
	if typed_manager != null:
		typed_manager.reset_touchscreen_positions()
	var store := get_store()
	if store != null:
		store.dispatch(U_InputActions.update_touchscreen_settings({
			"virtual_joystick_size": float(_joystick_size_slider.value),
			"button_size": float(_button_size_slider.value),
			"virtual_joystick_opacity": _defaults.virtual_joystick_opacity,
			"button_opacity": _defaults.button_opacity,
			"joystick_deadzone": _defaults.joystick_deadzone,
			"look_drag_sensitivity": _defaults.look_drag_sensitivity,
		}))
	_has_local_edits = false

func _on_edit_layout_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.open_overlay(StringName("edit_touch_controls")))

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _is_position_only_settings_update(settings_payload: Dictionary) -> bool:
	if settings_payload.is_empty():
		return false
	var slider_fields := [
		"virtual_joystick_size",
		"button_size",
		"virtual_joystick_opacity",
		"button_opacity",
		"joystick_deadzone",
		"look_drag_sensitivity",
	]
	for field in slider_fields:
		if settings_payload.has(field):
			return false
	return true

func _update_preview_from_sliders() -> void:
	if _preview_container == null:
		return

	var joystick_size: float = float(_joystick_size_slider.value)
	var button_size: float = float(_button_size_slider.value)
	var joystick_opacity: float = float(_joystick_opacity_slider.value)
	var button_opacity: float = float(_button_opacity_slider.value)
	var joystick_deadzone: float = float(_joystick_deadzone_slider.value)

	_preview_builder.update_preview_from_sliders(
		_preview_container,
		_preview_joystick,
		_preview_buttons,
		joystick_size,
		button_size,
		joystick_opacity,
		button_opacity,
		joystick_deadzone
	)

func _update_slider_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%.2f" % value

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	_configure_tooltips()

func _localize_labels() -> void:
	if _builder != null:
		_builder.localize_labels()
	if _joystick_size_text_label != null:
		_joystick_size_text_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LABEL_JOYSTICK_SIZE_KEY, "Joystick Size")
	if _button_size_text_label != null:
		_button_size_text_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LABEL_BUTTON_SIZE_KEY, "Button Size")
	if _joystick_opacity_text_label != null:
		_joystick_opacity_text_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LABEL_JOYSTICK_OPACITY_KEY, "Joystick Opacity")
	if _button_opacity_text_label != null:
		_button_opacity_text_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LABEL_BUTTON_OPACITY_KEY, "Button Opacity")
	if _joystick_deadzone_text_label != null:
		_joystick_deadzone_text_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LABEL_JOYSTICK_DEADZONE_KEY, "Joystick Deadzone")
	if _look_sensitivity_text_label != null:
		_look_sensitivity_text_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LABEL_LOOK_SENSITIVITY_KEY, "Look Drag Sensitivity")



func _log_local_slider_edit(_field: String, _value: float) -> void:
	# Intentionally left blank (was diagnostic logging).
	pass

func _close_overlay() -> void:
	var store := get_store()
	if store == null:
		return

	var state: Dictionary = store.get_state()
	var nav_slice: Dictionary = state.get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
		return

	# Main menu flow (standalone settings scenes):
	# - When accessed from the main menu, touchscreen_settings runs as a base
	#   scene (no overlays). Closing should return to the settings_menu scene.
	# - Use navigate_to_ui_screen action to trigger the transition via Redux.
	if shell == StringName("main_menu"):
		store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_menu"), "fade", 2))
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))
