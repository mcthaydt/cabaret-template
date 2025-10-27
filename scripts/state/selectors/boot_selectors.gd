extends RefCounted
class_name BootSelectors

## Selectors for boot state slice
##
## Pure functions that compute derived state from boot slice.
## Always pass the full boot state Dictionary to these functions.

## Check if boot sequence is complete
static func get_is_boot_complete(state: Dictionary) -> bool:
	return state.get("is_ready", false)

## Get current loading progress (0.0 to 1.0)
static func get_loading_progress(state: Dictionary) -> float:
	return state.get("loading_progress", 0.0)

## Get boot error message (empty string if no error)
static func get_boot_error(state: Dictionary) -> String:
	return state.get("error_message", "")

## Check if boot is in error state
static func get_is_boot_error(state: Dictionary) -> bool:
	return state.get("phase", "") == "error"

## Get current boot phase
static func get_boot_phase(state: Dictionary) -> String:
	return state.get("phase", "loading")
