@icon("res://editor_icons/manager.svg")
extends Node
class_name M_CursorManager

## Manages cursor visibility and lock state with ESC key toggle support
##
## This manager provides a simple interface for controlling the mouse cursor's
## visibility and lock state. Press ESC to toggle between locked/hidden (gameplay)
## and unlocked/visible (menu) modes.

signal cursor_state_changed(locked: bool, visible: bool)

## Current lock state of the cursor
var _is_locked: bool = true
## Current visibility state of the cursor
var _is_visible: bool = false

func _ready() -> void:
	add_to_group("cursor_manager")
	# Set initial state: hidden and locked
	_apply_cursor_state(true, false)

func _exit_tree() -> void:
	if is_in_group("cursor_manager"):
		remove_from_group("cursor_manager")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			toggle_cursor()
			get_viewport().set_input_as_handled()

## Toggles cursor between locked/hidden and unlocked/visible states
func toggle_cursor() -> void:
	if _is_locked:
		# Unlock and show cursor (for menus)
		set_cursor_state(false, true)
	else:
		# Lock and hide cursor (for gameplay)
		set_cursor_state(true, false)

## Sets both cursor lock and visibility states
func set_cursor_state(locked: bool, visible: bool) -> void:
	if _is_locked == locked and _is_visible == visible:
		return

	_apply_cursor_state(locked, visible)

## Sets whether the cursor is locked (confined to window and position-locked)
func set_cursor_locked(locked: bool) -> void:
	if _is_locked == locked:
		return

	_apply_cursor_state(locked, _is_visible)

## Sets whether the cursor is visible
func set_cursor_visible(visible: bool) -> void:
	if _is_visible == visible:
		return

	_apply_cursor_state(_is_locked, visible)

## Returns true if cursor is currently locked
func is_cursor_locked() -> bool:
	return _is_locked

## Returns true if cursor is currently visible
func is_cursor_visible() -> bool:
	return _is_visible

## Internal method to apply cursor state and emit signal
func _apply_cursor_state(locked: bool, visible: bool) -> void:
	_is_locked = locked
	_is_visible = visible

	# Apply to Godot's Input system
	if locked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	cursor_state_changed.emit(locked, visible)
