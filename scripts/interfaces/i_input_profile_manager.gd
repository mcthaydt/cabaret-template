extends Node
class_name I_InputProfileManager

## Minimal interface for M_InputProfileManager
##
## Phase 7 (cleanup_v4): Created for duck typing cleanup - removes has_method() checks
##
## Implementations:
## - M_InputProfileManager (production)
## - MockInputProfileManager (testing, if needed)

const RS_InputProfile = preload("res://scripts/input/resources/rs_input_profile.gd")

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
