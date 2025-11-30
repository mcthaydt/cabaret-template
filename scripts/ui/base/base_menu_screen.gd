@icon("res://resources/editor_icons/utility.svg")
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

const AnalogStickRepeater = preload("res://scripts/ui/utils/analog_stick_repeater.gd")

const STICK_DEADZONE: float = 0.25  # Must match project.godot ui_* action deadzone

var _stick_repeater: AnalogStickRepeater


func _ready() -> void:
	await super._ready()

	# Initialize analog stick repeater
	_stick_repeater = AnalogStickRepeater.new()
	_stick_repeater.on_navigate = _navigate_focus

func _process(delta: float) -> void:
	# Update analog stick repeater ONLY for analog input (not keyboard/D-pad)
	# This prevents double-firing since keyboard/D-pad have built-in repeat
	if _stick_repeater:
		_stick_repeater.update("ui_up", _is_stick_pressed_up(), delta)
		_stick_repeater.update("ui_down", _is_stick_pressed_down(), delta)
		_stick_repeater.update("ui_left", _is_stick_pressed_left(), delta)
		_stick_repeater.update("ui_right", _is_stick_pressed_right(), delta)


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
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
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

	if next_control != null and next_control.is_visible_in_tree() and not next_control.is_disabled():
		next_control.grab_focus()
