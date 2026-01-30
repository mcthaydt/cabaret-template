@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_EditTouchControlsOverlay

const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const I_INPUT_DEVICE_MANAGER := preload("res://scripts/interfaces/i_input_device_manager.gd")
const I_INPUT_PROFILE_MANAGER := preload("res://scripts/interfaces/i_input_profile_manager.gd")

@onready var _drag_mode_check: CheckButton = %DragModeCheck
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _save_button: Button = %SaveButton
@onready var _grid_overlay: ColorRect = $GridOverlay

@export var input_profile_manager: Node = null

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

var _mobile_controls: UI_MobileControls = null
var _profile_manager: Node = null
var _drag_mode_enabled: bool = false
var _original_positions: Dictionary = {}

func _on_panel_ready() -> void:
	_mobile_controls = _resolve_mobile_controls()
	_profile_manager = _resolve_input_profile_manager()

	_configure_focus_neighbors()
	_capture_original_positions()
	_set_drag_mode(false)

	_drag_mode_check.toggled.connect(_on_drag_mode_toggled)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_save_button.pressed.connect(_on_save_pressed)

func _resolve_input_profile_manager() -> Node:
	if input_profile_manager != null and is_instance_valid(input_profile_manager):
		return input_profile_manager

	var manager := U_ServiceLocator.try_get_service(INPUT_PROFILE_MANAGER_SERVICE)
	if manager != null:
		return manager

	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("input_profile_manager")

func _resolve_mobile_controls() -> UI_MobileControls:
	var input_manager := U_ServiceLocator.try_get_service(StringName("input_device_manager")) as I_INPUT_DEVICE_MANAGER
	if input_manager != null:
		var controls := input_manager.get_mobile_controls() as UI_MobileControls
		if controls != null and is_instance_valid(controls):
			return controls

	var tree := get_tree()
	if tree != null:
		var matches := tree.get_root().find_children("*", "UI_MobileControls", true, false)
		if not matches.is_empty():
			var first_match := matches[0] as UI_MobileControls
			if first_match != null and is_instance_valid(first_match):
				return first_match

		var fallback := tree.get_first_node_in_group("mobile_controls") as UI_MobileControls
		if fallback != null and is_instance_valid(fallback):
			return fallback
	return null

func _configure_focus_neighbors() -> void:
	var buttons: Array[Control] = []
	if _cancel_button != null:
		buttons.append(_cancel_button)
	if _reset_button != null:
		buttons.append(_reset_button)
	if _save_button != null:
		buttons.append(_save_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)

		var top_control: Control = _drag_mode_check
		if top_control != null:
			# From the toggle row, down moves into the primary action (Save),
			# and up/down from the bottom row returns to the toggle.
			var down_target: Control = _save_button if _save_button != null else buttons[0]
			top_control.focus_neighbor_bottom = top_control.get_path_to(down_target)
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(top_control)
				button.focus_neighbor_bottom = button.get_path_to(top_control)

func _exit_tree() -> void:
	if _drag_mode_enabled:
		_set_drag_mode(false)

func _capture_original_positions() -> void:
	_original_positions.clear()
	if _mobile_controls == null:
		return

	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as Control
	if joystick != null:
		_original_positions["virtual_joystick"] = joystick.position

	var buttons: Array = _mobile_controls.get_buttons()
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		var ctrl := button as Control
		var key := ""
		if "control_name" in button and button.control_name != StringName():
			key = String(button.control_name)
		elif "action" in button and button.action != StringName():
			key = String(button.action)
		if key.is_empty():
			continue
		_original_positions[key] = ctrl.position

func _set_drag_mode(enabled: bool) -> void:
	_drag_mode_enabled = enabled
	if _grid_overlay != null:
		_grid_overlay.visible = enabled

	if _mobile_controls == null:
		return

	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick")
	if joystick != null and "can_reposition" in joystick:
		joystick.can_reposition = enabled

	for button in _mobile_controls.get_buttons():
		if button == null or not is_instance_valid(button):
			continue
		if "can_reposition" in button:
			button.can_reposition = enabled

func _on_drag_mode_toggled(pressed: bool) -> void:
	_set_drag_mode(pressed)

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	if _drag_mode_enabled:
		_set_drag_mode(false)
	_restore_original_positions()
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var default_buttons: Array = []
	var default_joystick_position: Vector2 = Vector2(-1, -1)
	var typed_manager := _profile_manager as I_INPUT_PROFILE_MANAGER
	if typed_manager != null:
		default_buttons = typed_manager.reset_touchscreen_positions()
		default_joystick_position = typed_manager.get_default_joystick_position()

	var default_button_positions: Dictionary = {}
	for default_data in default_buttons:
		var action_value: Variant = default_data.get("action")
		var position_value: Variant = default_data.get("position")
		if position_value is Vector2:
			var action_key := ""
			if action_value is StringName:
				action_key = String(action_value)
			elif action_value is String:
				action_key = String(action_value)
			if not action_key.is_empty():
				default_button_positions[action_key] = position_value

	var store := get_store()
	if store != null:
		store.dispatch(U_InputActions.update_touchscreen_settings({
			"custom_button_positions": default_button_positions,
			"custom_joystick_position": default_joystick_position
		}))
	if _drag_mode_enabled:
		_set_drag_mode(false)

	# Visually move controls to default positions
	_apply_default_positions(default_buttons, default_joystick_position)
	if _mobile_controls != null and store != null:
		_mobile_controls.force_apply_positions(store.get_state(), false)
	_capture_original_positions()

func _apply_default_positions(default_buttons: Array, default_joystick_position: Vector2 = Vector2(-1, -1)) -> void:
	if _mobile_controls == null:
		return

	if default_buttons.is_empty():
		push_warning("EditTouchControlsOverlay: No default button positions returned from profile manager")

	# Apply joystick default position
	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as Control
	if joystick != null and default_joystick_position != Vector2(-1, -1):
		joystick.position = default_joystick_position

	# Apply button default positions
	var buttons: Array = _mobile_controls.get_buttons()
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		var ctrl := button as Control
		var button_action: StringName = StringName()
		if "action" in button:
			button_action = button.action

		# Find matching default position
		for default_data in default_buttons:
			var default_action: Variant = default_data.get("action")
			var default_position: Variant = default_data.get("position")
			if default_action is StringName and default_action == button_action and default_position is Vector2:
				ctrl.position = default_position
				break

func _on_save_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _drag_mode_enabled:
		_set_drag_mode(false)
	_close_overlay()

func _restore_original_positions() -> void:
	if _mobile_controls == null:
		return

	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as Control
	if joystick != null and _original_positions.has("virtual_joystick"):
		joystick.position = _original_positions["virtual_joystick"]

	var buttons: Array = _mobile_controls.get_buttons()
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		var ctrl := button as Control
		var key := ""
		if "control_name" in button and button.control_name != StringName():
			key = String(button.control_name)
		elif "action" in button and button.action != StringName():
			key = String(button.action)
		if key.is_empty():
			continue
		if _original_positions.has(key):
			ctrl.position = _original_positions[key]

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
	_on_cancel_pressed()
