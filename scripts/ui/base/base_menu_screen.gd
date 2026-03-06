@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_panel.gd"
class_name BaseMenuScreen

## Base class for full-screen UI scenes such as main menu, game over, and victory.
##
## Inherits the common store / focus / back handling from BasePanel and provides
## a dedicated hook for menu-specific setup.
##
## Implements manual analog stick navigation with repeat/echo behavior to work around
## Godot quirk where InputEventJoypadMotion.is_action() incorrectly matches both
## directions simultaneously and doesn't provide echo/repeat like keyboard input.

const ANALOG_STICK_REPEATER_PATH := "res://scripts/ui/utils/u_analog_stick_repeater.gd"

const STICK_DEADZONE: float = 0.25 # Must match project.godot ui_* action deadzone

var _stick_repeater: RefCounted = null

@export var motion_target_path: NodePath = NodePath()

func _ready() -> void:
	super._ready()

	# Initialize analog stick repeater
	var repeater_script: Script = load(ANALOG_STICK_REPEATER_PATH)
	if repeater_script != null:
		_stick_repeater = repeater_script.new()
		if _stick_repeater != null:
			_stick_repeater.on_navigate = _navigate_focus

func _process(delta: float) -> void:
	# Update analog stick repeater ONLY for analog input (not keyboard/D-pad)
	# This prevents double-firing since keyboard/D-pad have built-in repeat
	if _stick_repeater:
		_stick_repeater.update("ui_up", _is_stick_pressed_up(), delta)
		_stick_repeater.update("ui_down", _is_stick_pressed_down(), delta)
		_stick_repeater.update("ui_left", _is_stick_pressed_left(), delta)
		_stick_repeater.update("ui_right", _is_stick_pressed_right(), delta)

func _unhandled_input(event: InputEvent) -> void:
	# Swallow analog stick motion events used for navigation so Godot's built-in
	# ui_up/down/left/right handling does not also move focus. This ensures the
	# U_AnalogStickRepeater is the single source of analog navigation and prevents
	# double-skips when changing direction after a held repeat.
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_Y and abs(motion.axis_value) > STICK_DEADZONE:
			var viewport: Viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		elif motion.axis == JOY_AXIS_LEFT_X and abs(motion.axis_value) > STICK_DEADZONE:
			var viewport_x: Viewport = get_viewport()
			if viewport_x != null:
				viewport_x.set_input_as_handled()
	elif event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if (
			button.is_action_pressed("ui_up")
			or button.is_action_pressed("ui_down")
			or button.is_action_pressed("ui_left")
			or button.is_action_pressed("ui_right")
		):
			var viewport_button: Viewport = get_viewport()
			if viewport_button != null:
				viewport_button.set_input_as_handled()
	super._unhandled_input(event)


## Check if ONLY the analog stick (not D-pad/keyboard) is pressed in each direction
## Checks all connected joypads, not just device 0
func _is_stick_pressed_up() -> bool:
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(device, JOY_AXIS_LEFT_Y) < -STICK_DEADZONE:
			return true
	return false

func _is_stick_pressed_down() -> bool:
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(device, JOY_AXIS_LEFT_Y) > STICK_DEADZONE:
			return true
	return false

func _is_stick_pressed_left() -> bool:
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(device, JOY_AXIS_LEFT_X) < -STICK_DEADZONE:
			return true
	return false

func _is_stick_pressed_right() -> bool:
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(device, JOY_AXIS_LEFT_X) > STICK_DEADZONE:
			return true
	return false

func _navigate_focus(direction: StringName) -> void:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	if focused == null:
		return
	if not is_ancestor_of(focused):
		return

	var next_control: Control = null
	match direction:
		"ui_up":
			if focused.focus_neighbor_top != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_top) as Control
		"ui_down":
			if focused.focus_neighbor_bottom != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_bottom) as Control
		"ui_left":
			if focused.focus_neighbor_left != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_left) as Control
		"ui_right":
			if focused.focus_neighbor_right != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_right) as Control

	if next_control != null and next_control.is_visible_in_tree():
		_arm_focus_sound(focused)
		next_control.grab_focus()

func reset_analog_navigation() -> void:
	if _stick_repeater:
		_stick_repeater.reset()

func play_enter_animation() -> Tween:
	return U_UI_MOTION.play_enter(_resolve_motion_target(), motion_set)

func play_exit_animation() -> Tween:
	return U_UI_MOTION.play_exit(_resolve_motion_target(), motion_set)

func _resolve_motion_target() -> Node:
	var explicit_target := _resolve_explicit_motion_target()
	if explicit_target != null:
		return explicit_target

	var center_target := _resolve_center_panel_motion_target()
	if center_target != null:
		return center_target
	return self

func _resolve_explicit_motion_target() -> Node:
	if motion_target_path == NodePath():
		return null
	return get_node_or_null(motion_target_path)

func _resolve_center_panel_motion_target() -> Control:
	if not _has_backdrop_layer():
		return null
	var center := _find_center_container_with_panel(self)
	if center == null:
		return null
	return center

func _has_backdrop_layer() -> bool:
	var background := get_node_or_null("Background")
	if background is ColorRect:
		return true
	var overlay_background := get_node_or_null("OverlayBackground")
	if overlay_background is ColorRect:
		return true
	var color_rect := get_node_or_null("ColorRect")
	return color_rect is ColorRect

func _find_center_container_with_panel(root: Node) -> Control:
	for child in root.get_children():
		if not (child is Node):
			continue
		var child_node := child as Node
		if child_node is CenterContainer:
			var center := child_node as CenterContainer
			if _find_panel_descendant(center) != null:
				return center
		var nested := _find_center_container_with_panel(child_node)
		if nested != null:
			return nested
	return null

func _find_panel_descendant(root: Node) -> PanelContainer:
	if root is PanelContainer:
		return root as PanelContainer
	for child in root.get_children():
		if not (child is Node):
			continue
		var child_node := child as Node
		var panel := _find_panel_descendant(child_node)
		if panel != null:
			return panel
	return null
