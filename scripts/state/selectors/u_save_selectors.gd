extends RefCounted
class_name U_SaveSelectors

## Selectors for save state slice
##
## Provides type-safe getter functions for save-related state.

## Get whether a save operation is in progress
static func is_saving(save_state: Dictionary) -> bool:
	return bool(save_state.get("is_saving", false))

## Get whether a load operation is in progress
static func is_loading(save_state: Dictionary) -> bool:
	return bool(save_state.get("is_loading", false))

## Get whether a delete operation is in progress
static func is_deleting(save_state: Dictionary) -> bool:
	return bool(save_state.get("is_deleting", false))

## Get the last successfully saved slot index (-1 if none)
static func get_last_save_slot(save_state: Dictionary) -> int:
	return int(save_state.get("last_save_slot", -1))

## Get the current UI mode (0 = SAVE, 1 = LOAD)
static func get_current_mode(save_state: Dictionary) -> int:
	return int(save_state.get("current_mode", 1))

## Get the last error message (empty if no error)
static func get_last_error(save_state: Dictionary) -> String:
	return String(save_state.get("last_error", ""))

## Check if any operation is in progress
static func is_busy(save_state: Dictionary) -> bool:
	return is_saving(save_state) or is_loading(save_state) or is_deleting(save_state)
