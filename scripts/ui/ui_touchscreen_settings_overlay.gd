@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_TouchscreenSettingsOverlay

const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const RS_TouchscreenSettings := preload("res://scripts/ecs/resources/rs_touchscreen_settings.gd")
const VirtualJoystickScene := preload("res://scenes/ui/ui_virtual_joystick.tscn")
const VirtualButtonScene := preload("res://scenes/ui/ui_virtual_button.tscn")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")

@onready var _joystick_size_slider: HSlider = %JoystickSizeSlider
@onready var _button_size_slider: HSlider = %ButtonSizeSlider
@onready var _joystick_opacity_slider: HSlider = %JoystickOpacitySlider
@onready var _button_opacity_slider: HSlider = %ButtonOpacitySlider
@onready var _joystick_deadzone_slider: HSlider = %JoystickDeadzoneSlider

@onready var _joystick_size_label: Label = %JoystickSizeValue
@onready var _button_size_label: Label = %ButtonSizeValue
@onready var _joystick_opacity_label: Label = %JoystickOpacityValue
@onready var _button_opacity_label: Label = %ButtonOpacityValue
@onready var _joystick_deadzone_label: Label = %JoystickDeadzoneValue

@onready var _preview_container: Control = %PreviewContainer
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _edit_layout_button: Button = %EditLayoutButton

var _store_unsubscribe: Callable = Callable()
var _profile_manager: Node = null
var _preview_joystick: Control = null
var _preview_buttons: Array[Control] = []
var _defaults: RS_TouchscreenSettings = RS_TouchscreenSettings.new()
var _updating_from_state: bool = false
var _has_local_edits: bool = false
var _override_log_count: int = 0
var _local_edit_log_count: int = 0

func _on_store_ready(store: M_StateStore) -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()
	if store != null:
		_store_unsubscribe = store.subscribe(_on_state_changed)
		_on_state_changed({}, store.get_state())

func _on_panel_ready() -> void:
	_profile_manager = get_tree().get_first_node_in_group("input_profile_manager")

	_configure_focus_neighbors()
	_build_preview()
	_connect_signals()
	_update_preview_from_sliders()
	_update_edit_layout_visibility()

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()

func _build_preview() -> void:
	if _preview_container == null:
		return

	for child in _preview_container.get_children():
		child.queue_free()
	_preview_buttons.clear()
	_preview_joystick = null

	var viewport_size: Vector2 = _preview_container.size
	if viewport_size.is_zero_approx():
		viewport_size = Vector2(400, 220)

	var joystick_instance := VirtualJoystickScene.instantiate()
	if joystick_instance is Control:
		_preview_container.add_child(joystick_instance)
		_preview_joystick = joystick_instance
		joystick_instance.name = "PreviewJoystick"
		joystick_instance.process_mode = Node.PROCESS_MODE_DISABLED
		if joystick_instance is Control:
			joystick_instance.position = Vector2(40, viewport_size.y - 140)

	var actions := [
		StringName("jump"),
		StringName("sprint"),
		StringName("interact"),
		StringName("pause")
	]

	for index in actions.size():
		var button_instance := VirtualButtonScene.instantiate()
		if button_instance is Control:
			_preview_container.add_child(button_instance)
			button_instance.name = "PreviewButton_%s" % String(actions[index])
			if "action" in button_instance:
				button_instance.action = actions[index]
			if button_instance.has_method("_refresh_label"):
				button_instance._refresh_label()
			button_instance.process_mode = Node.PROCESS_MODE_DISABLED
			_preview_buttons.append(button_instance)

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
		var top_control: Control = _joystick_deadzone_slider
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
		_update_preview_from_sliders()
	)
	_button_size_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("button_size", value)
		_update_slider_label(_button_size_label, value)
		_update_preview_from_sliders()
	)
	_joystick_opacity_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("virtual_joystick_opacity", value)
		_update_slider_label(_joystick_opacity_label, value)
		_update_preview_from_sliders()
	)
	_button_opacity_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("button_opacity", value)
		_update_slider_label(_button_opacity_label, value)
		_update_preview_from_sliders()
	)
	_joystick_deadzone_slider.value_changed.connect(func(value: float) -> void:
		_has_local_edits = true
		_log_local_slider_edit("joystick_deadzone", value)
		_update_slider_label(_joystick_deadzone_label, value)
		_update_preview_from_sliders()
	)

	_apply_button.pressed.connect(_on_apply_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_edit_layout_button.pressed.connect(_on_edit_layout_pressed)

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

			if not overridden_fields.is_empty() and action_type != U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS and action_type != StringName(""):
				_override_log_count += 1

	_updating_from_state = true
	if not settings.is_empty():
		_joystick_size_slider.value = float(settings.get("virtual_joystick_size", _joystick_size_slider.value))
		_button_size_slider.value = float(settings.get("button_size", _button_size_slider.value))
		_joystick_opacity_slider.value = float(settings.get("virtual_joystick_opacity", _joystick_opacity_slider.value))
		_button_opacity_slider.value = float(settings.get("button_opacity", _button_opacity_slider.value))
		_joystick_deadzone_slider.value = float(settings.get("joystick_deadzone", _joystick_deadzone_slider.value))

	_update_slider_label(_joystick_size_label, _joystick_size_slider.value)
	_update_slider_label(_button_size_label, _button_size_slider.value)
	_update_slider_label(_joystick_opacity_label, _joystick_opacity_slider.value)
	_update_slider_label(_button_opacity_label, _button_opacity_slider.value)
	_update_slider_label(_joystick_deadzone_label, _joystick_deadzone_slider.value)

	_updating_from_state = false
	_update_preview_from_sliders()

func _on_apply_pressed() -> void:
	var store := get_store()
	if store == null:
		_close_overlay()
		return

	var joystick_size := float(_joystick_size_slider.value)
	var button_size := float(_button_size_slider.value)
	var joystick_opacity := float(_joystick_opacity_slider.value)
	var button_opacity := float(_button_opacity_slider.value)
	var joystick_deadzone := float(_joystick_deadzone_slider.value)

	var settings_updates := {
		"virtual_joystick_size": joystick_size,
		"button_size": button_size,
		"virtual_joystick_opacity": joystick_opacity,
		"button_opacity": button_opacity,
		"joystick_deadzone": joystick_deadzone,
	}

	store.dispatch(U_InputActions.update_touchscreen_settings(settings_updates))
	_has_local_edits = false
	_close_overlay()

func _on_cancel_pressed() -> void:
	_has_local_edits = false
	_close_overlay()

func _on_reset_pressed() -> void:
	_joystick_size_slider.value = _defaults.virtual_joystick_size
	_button_size_slider.value = _defaults.button_size
	_joystick_opacity_slider.value = _defaults.virtual_joystick_opacity
	_button_opacity_slider.value = _defaults.button_opacity
	_joystick_deadzone_slider.value = _defaults.joystick_deadzone

	_update_slider_label(_joystick_size_label, _joystick_size_slider.value)
	_update_slider_label(_button_size_label, _button_size_slider.value)
	_update_slider_label(_joystick_opacity_label, _joystick_opacity_slider.value)
	_update_slider_label(_button_opacity_label, _button_opacity_slider.value)
	_update_slider_label(_joystick_deadzone_label, _joystick_deadzone_slider.value)

	_update_preview_from_sliders()

	if _profile_manager != null and _profile_manager.has_method("reset_touchscreen_positions"):
		_profile_manager.reset_touchscreen_positions()
	var store := get_store()
	if store != null:
		store.dispatch(U_InputActions.update_touchscreen_settings({
			"virtual_joystick_size": _defaults.virtual_joystick_size,
			"button_size": _defaults.button_size,
			"virtual_joystick_opacity": _defaults.virtual_joystick_opacity,
			"button_opacity": _defaults.button_opacity,
			"joystick_deadzone": _defaults.joystick_deadzone,
		}))
	_has_local_edits = false

func _on_edit_layout_pressed() -> void:
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.open_overlay(StringName("edit_touch_controls")))

func _on_back_pressed() -> void:
	print("[TouchscreenSettingsOverlay] _on_back_pressed invoked")
	_close_overlay()

func _is_position_only_settings_update(settings_payload: Dictionary) -> bool:
	if settings_payload.is_empty():
		return false
	var slider_fields := [
		"virtual_joystick_size",
		"button_size",
		"virtual_joystick_opacity",
		"button_opacity",
		"joystick_deadzone"
	]
	for field in slider_fields:
		if settings_payload.has(field):
			return false
	return true

func _update_preview_from_sliders() -> void:
	var joystick_size: float = float(_joystick_size_slider.value)
	if joystick_size < 0.01:
		joystick_size = 0.01

	var button_size: float = float(_button_size_slider.value)
	if button_size < 0.01:
		button_size = 0.01

	var joystick_opacity: float = clampf(float(_joystick_opacity_slider.value), 0.0, 1.0)
	var button_opacity: float = clampf(float(_button_opacity_slider.value), 0.0, 1.0)
	var joystick_deadzone: float = clampf(float(_joystick_deadzone_slider.value), 0.0, 1.0)

	if _preview_joystick != null and is_instance_valid(_preview_joystick):
		_preview_joystick.scale = Vector2.ONE * joystick_size
		var color: Color = _preview_joystick.modulate
		color.a = joystick_opacity
		_preview_joystick.modulate = color
		if "deadzone" in _preview_joystick:
			_preview_joystick.deadzone = joystick_deadzone

	for button in _preview_buttons:
		if button == null or not is_instance_valid(button):
			continue
		button.scale = Vector2.ONE * button_size
		var button_color: Color = button.modulate
		button_color.a = button_opacity
		button.modulate = button_color

	var preview_size: Vector2 = _preview_container.size
	if preview_size.is_zero_approx():
		preview_size = Vector2(520, 220)

	if _preview_joystick != null and is_instance_valid(_preview_joystick):
		var base_joystick_size: Vector2 = _preview_joystick.size
		if base_joystick_size.is_zero_approx():
			base_joystick_size = _preview_joystick.custom_minimum_size
		var joystick_scaled: Vector2 = base_joystick_size * joystick_size
		var padding: float = 24.0
		_preview_joystick.position = Vector2(
			padding,
			max(padding, preview_size.y - padding - joystick_scaled.y)
		)

	var button_padding: float = 24.0
	var button_spacing: float = 12.0
	var base_button_size: Vector2 = Vector2.ONE * 100.0
	if not _preview_buttons.is_empty():
		var sample_button: Control = _preview_buttons[0]
		if sample_button != null and is_instance_valid(sample_button):
			base_button_size = sample_button.size
			if base_button_size.is_zero_approx():
				base_button_size = sample_button.custom_minimum_size
	var button_scaled_size: Vector2 = base_button_size * button_size
	var total_width: float = float(_preview_buttons.size()) * button_scaled_size.x
	if _preview_buttons.size() > 1:
		total_width += float(_preview_buttons.size() - 1) * button_spacing

	# Position buttons in a 2x2 grid
	var grid_cols: int = 2
	var grid_rows: int = 2
	var grid_width: float = float(grid_cols) * button_scaled_size.x + float(grid_cols - 1) * button_spacing
	var grid_height: float = float(grid_rows) * button_scaled_size.y + float(grid_rows - 1) * button_spacing

	var grid_start_x: float = max(button_padding, preview_size.x - button_padding - grid_width)
	var grid_start_y: float = max(button_padding, preview_size.y - button_padding - grid_height)

	for index in _preview_buttons.size():
		var button: Control = _preview_buttons[index]
		if button == null or not is_instance_valid(button):
			continue
		var col: int = index % grid_cols
		var row: int = index / grid_cols
		button.position = Vector2(
			grid_start_x + float(col) * (button_scaled_size.x + button_spacing),
			grid_start_y + float(row) * (button_scaled_size.y + button_spacing)
		)

func _update_slider_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%.2f" % value

func _log_local_slider_edit(_field: String, _value: float) -> void:
	# Intentionally left blank (was diagnostic logging).
	pass

func _close_overlay() -> void:
	var store := get_store()
	if store == null:
		print("[TouchscreenSettingsOverlay] _close_overlay store is null; aborting")
		return

	var state: Dictionary = store.get_state()
	var nav_slice: Dictionary = state.get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	print(
		"[TouchscreenSettingsOverlay] _close_overlay shell=%s overlay_stack_size=%d" % [
			str(shell),
			overlay_stack.size()
		]
	)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
		return

	# Main menu flow (standalone settings scenes):
	# - When accessed from the main menu, touchscreen_settings runs as a base
	#   scene (no overlays). Closing should return to the settings_menu scene.
	# - Use navigate_to_ui_screen action to trigger the transition via Redux.
	if shell == StringName("main_menu"):
		store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_menu"), "fade", 1))
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))
