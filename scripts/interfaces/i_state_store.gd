extends Resource
class_name I_StateStore

## Minimal interface for M_StateStore
##
## Provides only the core methods that systems actually need, avoiding
## tight coupling to internal store implementation details.
##
## Phase 10B-8 (T142a): Created to enable dependency injection and testing
##
## Implementations:
## - M_StateStore (production)
## - MockStateStore (testing)

## Dispatch an action to update state
##
## @param action: Dictionary with "type" (StringName) and optional "payload"
func dispatch(_action: Dictionary) -> void:
	push_error("I_StateStore.dispatch not implemented")

## Subscribe to state changes
##
## @param callback: Callable(action: Dictionary, new_state: Dictionary)
## @return Callable: Unsubscribe function to call when done
func subscribe(_callback: Callable) -> Callable:
	push_error("I_StateStore.subscribe not implemented")
	return Callable()

## Get full state snapshot (deep copy)
##
## @return Dictionary: Complete state tree
func get_state() -> Dictionary:
	push_error("I_StateStore.get_state not implemented")
	return {}

## Get specific state slice (deep copy)
##
## @param slice_name: Name of the slice (e.g., "gameplay", "navigation")
## @return Dictionary: Slice state snapshot
func get_slice(_slice_name: StringName) -> Dictionary:
	push_error("I_StateStore.get_slice not implemented")
	return {}

## Check if store is ready for use
##
## @return bool: true if initialization complete
func is_ready() -> bool:
	push_error("I_StateStore.is_ready not implemented")
	return false
