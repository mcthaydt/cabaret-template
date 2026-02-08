extends Node
class_name I_InputProfileManager

## Minimal interface for M_InputProfileManager
##
## Phase 7 (cleanup_v4): Created for duck typing cleanup - removes has_method() checks
##
## Implementations:
## - M_InputProfileManager (production)
## - MockInputProfileManager (testing, if needed)

## Get the currently active input profile
##
## @return RS_InputProfile: The active profile, or null if none loaded
func get_active_profile() -> RS_InputProfile:
	push_error("I_InputProfileManager.get_active_profile not implemented")
	return null

## Reset all input bindings to default values
##
## Dispatches reset action to Redux store to restore default bindings
func reset_to_defaults() -> void:
	push_error("I_InputProfileManager.reset_to_defaults not implemented")

## Reset a single action's bindings to defaults
##
## Removes custom bindings for the specified action via Redux dispatch
##
## @param _action: Action name to reset
func reset_action(_action: StringName) -> void:
	push_error("I_InputProfileManager.reset_action not implemented")

## Get default touchscreen control positions
##
## Returns array of button position dictionaries from the default profile
##
## @return Array[Dictionary]: Default positions for virtual controls
func reset_touchscreen_positions() -> Array[Dictionary]:
	push_error("I_InputProfileManager.reset_touchscreen_positions not implemented")
	return []

## Get default joystick position
##
## Returns the default position for the virtual joystick from the default profile
##
## @return Vector2: Default joystick position, or Vector2(-1, -1) if not configured
func get_default_joystick_position() -> Vector2:
	push_error("I_InputProfileManager.get_default_joystick_position not implemented")
	return Vector2(-1, -1)
