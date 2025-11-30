@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_panel.gd"
class_name BaseMenuScreen

## Base class for full-screen UI scenes such as main menu, game over, and victory.
##
## Inherits the common store / focus / back handling from BasePanel and provides
## a dedicated hook for menu-specific setup.
##
## Implements manual analog stick navigation to work around Godot quirk where
## InputEventJoypadMotion.is_action() incorrectly matches both directions simultaneously.

func _ready() -> void:
	await super._ready()

func _input(event: InputEvent) -> void:
	# Manual analog stick navigation fix for Godot quirk:
	# InputEventJoypadMotion.is_action() incorrectly matches both directions
	# simultaneously, breaking built-in UI navigation. We intercept analog stick
	# input and manually handle focus navigation using Input.is_action_just_pressed()
	# which correctly checks axis direction.
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		# Only intercept ui navigation axes (vertical/horizontal)
		if motion.axis == JOY_AXIS_LEFT_Y or motion.axis == JOY_AXIS_LEFT_X:
			if Input.is_action_just_pressed("ui_up"):
				_navigate_focus("ui_up")
				get_viewport().set_input_as_handled()
			elif Input.is_action_just_pressed("ui_down"):
				_navigate_focus("ui_down")
				get_viewport().set_input_as_handled()
			elif Input.is_action_just_pressed("ui_left"):
				_navigate_focus("ui_left")
				get_viewport().set_input_as_handled()
			elif Input.is_action_just_pressed("ui_right"):
				_navigate_focus("ui_right")
				get_viewport().set_input_as_handled()

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
