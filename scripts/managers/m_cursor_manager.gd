@icon("res://assets/editor_icons/manager.svg")
extends Node
class_name M_CursorManager

## Manages cursor visibility and lock state
##
## T071: Refactored to remove direct pause input handling.
## This manager provides a simple interface for controlling the mouse cursor's
## visibility and lock state. Cursor state is controlled via explicit calls from
## M_PauseManager or M_SceneManager, not via direct input handling.
##
## Does NOT handle input directly - cursor changes flow through pause/navigation systems.

signal cursor_state_changed(locked: bool, visible: bool)

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

## Current lock state of the cursor
var _is_locked: bool = true
## Current visibility state of the cursor
var _is_visible: bool = false

func _ready() -> void:
	var service_name := StringName("cursor_manager")
	if not U_SERVICE_LOCATOR.has(service_name):
		U_SERVICE_LOCATOR.register(service_name, self)
	# Set initial state: hidden and locked
	_apply_cursor_state(true, false)

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
