@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_GamepadSettingsOverlay

const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")

const TITLE_KEY := &"settings.gamepad.title"
const LABEL_LEFT_DEADZONE_KEY := &"settings.gamepad.label.left_deadzone"
const LABEL_RIGHT_DEADZONE_KEY := &"settings.gamepad.label.right_deadzone"
const LABEL_VIBRATION_ENABLED_KEY := &"settings.gamepad.label.vibration_enabled"
const LABEL_VIBRATION_INTENSITY_KEY := &"settings.gamepad.label.vibration_intensity"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.gamepad.button.reset_defaults"
const PREVIEW_ENTER_PROMPT_KEY := &"settings.gamepad.preview.enter"
const PREVIEW_EXIT_PROMPT_KEY := &"settings.gamepad.preview.exit"

const TOOLTIP_LEFT_DEADZONE_KEY := &"settings.gamepad.tooltip.left_deadzone"
const TOOLTIP_RIGHT_DEADZONE_KEY := &"settings.gamepad.tooltip.right_deadzone"
const TOOLTIP_VIBRATION_ENABLED_KEY := &"settings.gamepad.tooltip.vibration_enabled"
const TOOLTIP_VIBRATION_INTENSITY_KEY := &"settings.gamepad.tooltip.vibration_intensity"
const TOOLTIP_PREVIEW_KEY := &"settings.gamepad.tooltip.preview"

@onready var _title_label: Label = $CenterContainer/Panel/VBox/Title
@onready var _left_deadzone_label: Label = $CenterContainer/Panel/VBox/LeftRow/LeftLabel
@onready var _right_deadzone_label: Label = $CenterContainer/Panel/VBox/RightRow/RightLabel
@onready var _vibration_enabled_label: Label = $CenterContainer/Panel/VBox/VibrationEnableRow/VibrationEnableLabel
@onready var _vibration_intensity_label: Label = $CenterContainer/Panel/VBox/VibrationRow/VibrationLabel
@onready var _left_slider: HSlider = %LeftDeadzoneSlider
@onready var _right_slider: HSlider = %RightDeadzoneSlider
@onready var _left_label: Label = %LeftDeadzoneValue
@onready var _right_label: Label = %RightDeadzoneValue
@onready var _vibration_checkbox: CheckButton = %VibrationCheck
@onready var _vibration_slider: HSlider = %VibrationSlider
@onready var _vibration_label: Label = %VibrationValue
@onready var _preview: UI_GamepadStickPreview = %StickPreview
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _preview_enter_prompt: UI_ButtonPrompt = %EnterPrompt
@onready var _preview_exit_prompt: UI_ButtonPrompt = %ExitPrompt

var _store_unsubscribe: Callable = Callable()
var _current_device_id: int = -1
var _left_stick_raw: Vector2 = Vector2.ZERO
var _right_stick_raw: Vector2 = Vector2.ZERO
var _left_stick_processed: Vector2 = Vector2.ZERO
var _right_stick_processed: Vector2 = Vector2.ZERO
var _updating_from_state: bool = false
var _preview_active: bool = false

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_on_state_changed({}, store.get_state())

func _on_panel_ready() -> void:
	_configure_focus_neighbors()
	_connect_control_signals()
	_localize_labels()
	_configure_tooltips()
	_configure_preview_prompts()

func _configure_preview_prompts() -> void:
	_preview_active = false
	_localize_preview_prompts()
	_update_preview_prompt_visibility()
	if _preview != null:
		_preview.set_active(false)

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = []
	if _left_slider != null:
		vertical_controls.append(_left_slider)
	if _right_slider != null:
		vertical_controls.append(_right_slider)
	if _vibration_checkbox != null:
		vertical_controls.append(_vibration_checkbox)
	if _vibration_slider != null:
		vertical_controls.append(_vibration_slider)
	if _preview != null:
		vertical_controls.append(_preview)

	if not vertical_controls.is_empty():
		U_FocusConfigurator.configure_vertical_focus(vertical_controls, false)

	if _preview != null and _apply_button != null:
		_preview.focus_neighbor_bottom = _preview.get_path_to(_apply_button)

	var buttons: Array[Control] = []
	if _cancel_button != null:
		buttons.append(_cancel_button)
	if _reset_button != null:
		buttons.append(_reset_button)
	if _apply_button != null:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		for button in buttons:
			if _preview != null:
				button.focus_neighbor_top = button.get_path_to(_preview)
				button.focus_neighbor_bottom = button.get_path_to(_preview)

func _connect_control_signals() -> void:
	_left_slider.value_changed.connect(func(value: float) -> void:
		_update_slider_label(_left_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
	)
	_right_slider.value_changed.connect(func(value: float) -> void:
		_update_slider_label(_right_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
	)
	_vibration_slider.value_changed.connect(func(value: float) -> void:
		_update_slider_label(_vibration_label, value)
		if not _updating_from_state:
			U_UISoundPlayer.play_slider_tick()
	)
	_vibration_checkbox.toggled.connect(_on_vibration_toggled)
	_apply_button.pressed.connect(_on_apply_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)

func _configure_tooltips() -> void:
	if _left_slider != null:
		_left_slider.tooltip_text = _localize_with_fallback(
			TOOLTIP_LEFT_DEADZONE_KEY,
			"Adjust deadzone for left stick movement."
		)
	if _right_slider != null:
		_right_slider.tooltip_text = _localize_with_fallback(
			TOOLTIP_RIGHT_DEADZONE_KEY,
			"Adjust deadzone for right stick camera/look."
		)
	if _vibration_checkbox != null:
		_vibration_checkbox.tooltip_text = _localize_with_fallback(
			TOOLTIP_VIBRATION_ENABLED_KEY,
			"Enable or disable gamepad vibration feedback."
		)
	if _vibration_slider != null:
		_vibration_slider.tooltip_text = _localize_with_fallback(
			TOOLTIP_VIBRATION_INTENSITY_KEY,
			"Adjust vibration strength."
		)
	if _preview != null:
		_preview.tooltip_text = _localize_with_fallback(
			TOOLTIP_PREVIEW_KEY,
			"Focus and press confirm to test stick input."
		)

func _localize_preview_prompts() -> void:
	if _preview_enter_prompt != null:
		_preview_enter_prompt.show_prompt(
			StringName("ui_accept"),
			_localize_with_fallback(PREVIEW_ENTER_PROMPT_KEY, "Press to test sticks")
		)
	if _preview_exit_prompt != null:
		_preview_exit_prompt.show_prompt(
			StringName("ui_cancel"),
			_localize_with_fallback(PREVIEW_EXIT_PROMPT_KEY, "Press to exit preview")
		)

func _update_preview_prompt_visibility() -> void:
	if _preview_enter_prompt != null:
		_preview_enter_prompt.visible = not _preview_active
	if _preview_exit_prompt != null:
		_preview_exit_prompt.visible = _preview_active

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var action_type: StringName = StringName("")
	if _action.has("type"):
		action_type = _action.get("type", StringName(""))

	var settings := U_InputSelectors.get_gamepad_settings(state)
	var overridden_fields: Array[String] = []
	if not settings.is_empty():
		var left_from_state := float(settings.get("left_stick_deadzone", _left_slider.value))
		var right_from_state := float(settings.get("right_stick_deadzone", _right_slider.value))
		var vibration_enabled_from_state := bool(settings.get("vibration_enabled", true))
		var vibration_from_state := float(settings.get("vibration_intensity", _vibration_slider.value))

		if not is_equal_approx(_left_slider.value, left_from_state):
			overridden_fields.append("left_stick_deadzone")
		if not is_equal_approx(_right_slider.value, right_from_state):
			overridden_fields.append("right_stick_deadzone")
		if _vibration_checkbox.button_pressed != vibration_enabled_from_state:
			overridden_fields.append("vibration_enabled")
		if not is_equal_approx(_vibration_slider.value, vibration_from_state):
			overridden_fields.append("vibration_intensity")

	_updating_from_state = true
	if not settings.is_empty():
		_left_slider.value = float(settings.get("left_stick_deadzone", _left_slider.value))
		_right_slider.value = float(settings.get("right_stick_deadzone", _right_slider.value))
		_vibration_checkbox.button_pressed = bool(settings.get("vibration_enabled", true))
		_vibration_slider.value = float(settings.get("vibration_intensity", _vibration_slider.value))
	_update_slider_label(_left_label, _left_slider.value)
	_update_slider_label(_right_label, _right_slider.value)
	_update_slider_label(_vibration_label, _vibration_slider.value)
	_updating_from_state = false

	var gameplay: Variant = state.get("gameplay", {})
	if gameplay is Dictionary and (gameplay as Dictionary).has("input"):
		var input_state: Variant = (gameplay as Dictionary)["input"]
		if input_state is Dictionary:
			var connected := bool((input_state as Dictionary).get("gamepad_connected", false))
			if connected:
				_current_device_id = int((input_state as Dictionary).get("gamepad_device_id", -1))
			else:
				_current_device_id = -1

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		_close_overlay()
		return

	# Capture all values BEFORE dispatching any actions
	# (dispatching triggers state_changed which can modify UI values)
	var left_deadzone := _left_slider.value
	var right_deadzone := _right_slider.value
	var vibration_enabled := _vibration_checkbox.button_pressed
	var vibration_intensity := _vibration_slider.value

	store.dispatch(U_InputActions.update_gamepad_deadzone("left", left_deadzone))
	store.dispatch(U_InputActions.update_gamepad_deadzone("right", right_deadzone))
	store.dispatch(U_InputActions.toggle_vibration(vibration_enabled))
	store.dispatch(U_InputActions.set_vibration_intensity(vibration_intensity))
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	var defaults := RS_GamepadSettings.new()

	_left_slider.value = defaults.left_stick_deadzone
	_right_slider.value = defaults.right_stick_deadzone
	_vibration_checkbox.button_pressed = defaults.vibration_enabled
	_vibration_slider.value = defaults.vibration_intensity

	_update_slider_label(_left_label, _left_slider.value)
	_update_slider_label(_right_label, _right_slider.value)
	_update_slider_label(_vibration_label, _vibration_slider.value)

	if store != null:
		store.dispatch(U_InputActions.update_gamepad_deadzone("left", defaults.left_stick_deadzone))
		store.dispatch(U_InputActions.update_gamepad_deadzone("right", defaults.right_stick_deadzone))
		store.dispatch(U_InputActions.toggle_vibration(defaults.vibration_enabled))
		store.dispatch(U_InputActions.set_vibration_intensity(defaults.vibration_intensity))

func _close_overlay() -> void:
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _process(delta: float) -> void:
	if _preview == null or not _preview.has_focus() or not _preview_active:
		super._process(delta)
	_update_preview_vectors()

func _unhandled_input(event: InputEvent) -> void:
	if _preview != null and _preview.has_focus():
		if event.is_action_pressed("ui_accept"):
			_preview_active = true
			if _preview != null:
				_preview.set_active(true)
			_update_preview_prompt_visibility()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return

		if _preview_active and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause")):
			_preview_active = false
			if _preview != null:
				_preview.set_active(false)
			_update_preview_prompt_visibility()
			var viewport_cancel := get_viewport()
			if viewport_cancel != null:
				viewport_cancel.set_input_as_handled()
			return

	super._unhandled_input(event)

func _update_preview_vectors() -> void:
	if _preview == null:
		return

	# Only show live joystick preview when the preview control is focused.
	# This keeps the stick "free" for navigation and slider control until
	# the user explicitly selects the preview row.
	if not _preview_active or not _preview.has_focus() or _current_device_id < 0:
		_preview.update_vectors(Vector2.ZERO, Vector2.ZERO)
		_left_stick_raw = Vector2.ZERO
		_right_stick_raw = Vector2.ZERO
		_left_stick_processed = Vector2.ZERO
		_right_stick_processed = Vector2.ZERO
		return

	# Read raw stick values
	# Note: Godot's joystick Y-axis is positive=down, negative=up
	# For display purposes, invert Y so visual matches physical (up=up, down=down)
	_left_stick_raw = Vector2(
		Input.get_joy_axis(_current_device_id, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(_current_device_id, JOY_AXIS_LEFT_Y)  # Invert Y for display
	)

	_right_stick_raw = Vector2(
		Input.get_joy_axis(_current_device_id, JOY_AXIS_RIGHT_X),
		-Input.get_joy_axis(_current_device_id, JOY_AXIS_RIGHT_Y)  # Invert Y for display
	)

	# Apply deadzone to get processed values
	_left_stick_processed = RS_GamepadSettings.apply_deadzone(
		_left_stick_raw,
		_left_slider.value,
		RS_GamepadSettings.DeadzoneCurve.LINEAR
	)
	_right_stick_processed = RS_GamepadSettings.apply_deadzone(
		_right_stick_raw,
		_right_slider.value,
		RS_GamepadSettings.DeadzoneCurve.LINEAR
	)

	# Update visual preview with processed values
	_preview.update_vectors(_left_stick_processed, _right_stick_processed, _left_stick_raw, _right_stick_raw)

func _update_slider_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%.2f" % value

func _on_vibration_toggled(enabled: bool) -> void:
	# Test vibration when toggled by user (not when updating from state)
	if enabled and _current_device_id >= 0 and not _updating_from_state:
		var intensity := _vibration_slider.value
		Input.start_joy_vibration(_current_device_id, 0.5 * intensity, 0.3 * intensity, 0.3)

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	_configure_tooltips()

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = _localize_with_fallback(TITLE_KEY, "Gamepad Settings")
	if _left_deadzone_label != null:
		_left_deadzone_label.text = _localize_with_fallback(LABEL_LEFT_DEADZONE_KEY, "Left Deadzone")
	if _right_deadzone_label != null:
		_right_deadzone_label.text = _localize_with_fallback(LABEL_RIGHT_DEADZONE_KEY, "Right Deadzone")
	if _vibration_enabled_label != null:
		_vibration_enabled_label.text = _localize_with_fallback(LABEL_VIBRATION_ENABLED_KEY, "Enable Vibration")
	if _vibration_intensity_label != null:
		_vibration_intensity_label.text = _localize_with_fallback(LABEL_VIBRATION_INTENSITY_KEY, "Vibration Intensity")

	_localize_preview_prompts()
	_update_preview_prompt_visibility()

	if _cancel_button != null:
		_cancel_button.text = _localize_with_fallback(&"common.cancel", "Cancel")
	if _reset_button != null:
		_reset_button.text = _localize_with_fallback(BUTTON_RESET_DEFAULTS_KEY, "Reset to Defaults")
	if _apply_button != null:
		_apply_button.text = _localize_with_fallback(&"common.apply", "Apply")

func _localize_with_fallback(key: StringName, fallback: String) -> String:
	var localized: String = U_LOCALIZATION_UTILS.localize(key)
	if localized == String(key):
		return fallback
	return localized

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
