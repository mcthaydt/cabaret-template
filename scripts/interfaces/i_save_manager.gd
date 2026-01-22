extends Node
class_name I_SaveManager

## Minimal interface for M_SaveManager
##
## Phase 4 (cleanup_v4): Created for duck typing cleanup - removes has_method() checks
##
## Implementations:
## - M_SaveManager (production)
## - MockSaveManager (testing)

## Check if save/load operations are currently in progress
##
## @return bool: True if save or load operation is locked
func is_locked() -> bool:
	push_error("I_SaveManager.is_locked not implemented")
	return false

## Request an autosave with priority
##
## @param _priority: Priority level (0=NORMAL, 1=HIGH, 2=CRITICAL)
func request_autosave(_priority: int = 0) -> void:
	push_error("I_SaveManager.request_autosave not implemented")

## Check if any save files exist
##
## @return bool: True if any save slot has a valid save file
func has_any_saves() -> bool:
	push_error("I_SaveManager.has_any_saves not implemented")
	return false

## Save current game state to a slot
##
## @param _slot_id: Slot identifier (autosave, slot_01, slot_02, slot_03)
## @return Error: OK on success, error code on failure
func save_to_slot(_slot_id: StringName) -> Error:
	push_error("I_SaveManager.save_to_slot not implemented")
	return ERR_UNAVAILABLE

## Load game state from a slot
##
## @param _slot_id: Slot identifier (autosave, slot_01, slot_02, slot_03)
## @return Error: OK on success, error code on failure
func load_from_slot(_slot_id: StringName) -> Error:
	push_error("I_SaveManager.load_from_slot not implemented")
	return ERR_UNAVAILABLE
