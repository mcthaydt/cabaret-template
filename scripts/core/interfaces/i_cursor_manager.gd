extends Node
class_name I_CursorManager

## Interface for M_CursorManager
##
## Implementations:
## - M_CursorManager (production)

func set_cursor_state(_locked: bool, _visible: bool) -> void:
	push_error("I_CursorManager.set_cursor_state not implemented")

func set_cursor_locked(_locked: bool) -> void:
	push_error("I_CursorManager.set_cursor_locked not implemented")

func set_cursor_visible(_visible: bool) -> void:
	push_error("I_CursorManager.set_cursor_visible not implemented")

func is_cursor_locked() -> bool:
	push_error("I_CursorManager.is_cursor_locked not implemented")
	return false

func is_cursor_visible() -> bool:
	push_error("I_CursorManager.is_cursor_visible not implemented")
	return false
