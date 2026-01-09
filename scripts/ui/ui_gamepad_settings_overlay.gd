@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_GamepadSettingsOverlay

const RS_GamepadSettings := preload("res://scripts/input/resources/rs_gamepad_settings.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const UI_GamepadStickPreview := preload("res://scripts/ui/ui_gamepad_stick_preview.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")

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
	_configure_preview_prompts()

func _configure_preview_prompts() -> void:
	if _preview_enter_prompt != null:
		_preview_enter_prompt.show_prompt(StringName("ui_accept"), "Press to test sticks")
	if _preview_exit_prompt != null:
		_preview_exit_prompt.show_prompt(StringName("ui_cancel"), "Press to exit preview")
		_preview_exit_prompt.visible = false
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
			if _preview_enter_prompt != null:
				_preview_enter_prompt.visible = false
			if _preview_exit_prompt != null:
				_preview_exit_prompt.visible = true
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return

		if _preview_active and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause")):
			_preview_active = false
			if _preview != null:
				_preview.set_active(false)
			if _preview_enter_prompt != null:
				_preview_enter_prompt.visible = true
			if _preview_exit_prompt != null:
				_preview_exit_prompt.visible = false
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

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
