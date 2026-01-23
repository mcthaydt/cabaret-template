extends "res://scripts/ui/base/base_overlay.gd"
class_name I_RebindOverlay

## Interface for input rebinding overlay implementations
## Phase 9 (Duck Typing Cleanup): Created to replace has_method() checks with explicit typing
## Implementations: UI_InputRebindingOverlay

## Begin capturing input for an action
func begin_capture(_action: StringName, _mode: String) -> void:
	push_error("I_RebindOverlay.begin_capture not implemented")

## Reset a single action to its default bindings
func reset_single_action(_action: StringName) -> void:
	push_error("I_RebindOverlay.reset_single_action not implemented")

## Connect focus handlers for an action row
func connect_row_focus_handlers(_row: Control, _add_button: Button, _replace_button: Button, _reset_button: Button) -> void:
	push_error("I_RebindOverlay.connect_row_focus_handlers not implemented")

## Check if an action is reserved (cannot be rebound)
func is_reserved(_action: StringName) -> bool:
	push_error("I_RebindOverlay.is_reserved not implemented")
	return false

## Refresh the binding display for all actions
func refresh_bindings() -> void:
	push_error("I_RebindOverlay.refresh_bindings not implemented")

## Enable or disable the reset button
func set_reset_button_enabled(_enabled: bool) -> void:
	push_error("I_RebindOverlay.set_reset_button_enabled not implemented")

## Configure focus neighbors for gamepad navigation
func configure_focus_neighbors() -> void:
	push_error("I_RebindOverlay.configure_focus_neighbors not implemented")

## Apply focus to the first focusable control
func apply_focus() -> void:
	push_error("I_RebindOverlay.apply_focus not implemented")

## Get the active device category (keyboard or gamepad)
func get_active_device_category() -> String:
	push_error("I_RebindOverlay.get_active_device_category not implemented")
	return "keyboard"

## Check if an action has custom bindings
func is_binding_custom(_action: StringName) -> bool:
	push_error("I_RebindOverlay.is_binding_custom not implemented")
	return false

## Get the active input profile
func get_active_profile() -> RS_InputProfile:
	push_error("I_RebindOverlay.get_active_profile not implemented")
	return null
