extends RefCounted
class_name U_SignalBatcher

## Batches signal emissions per physics frame for performance.
##
## Accumulates dirty slices during a frame and emits signals once per slice
## during physics_process. Prevents signal spam from rapid dispatches while
## keeping state updates synchronous.

var _pending_slice_updates: Dictionary = {}  # slice_name -> latest slice_state

## Mark a slice as dirty (needs signal emission)
## Stores latest state, overwriting previous if already pending
func mark_slice_dirty(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name == StringName():
		push_warning("U_SignalBatcher.mark_slice_dirty: empty slice_name")
		return
	
	# Store deep copy to prevent mutation
	_pending_slice_updates[slice_name] = slice_state.duplicate(true)

## Flush all pending signals by calling emit_callback for each dirty slice
## Clears pending updates after emission
func flush(emit_callback: Callable) -> void:
	if emit_callback == Callable() or not emit_callback.is_valid():
		push_error("U_SignalBatcher.flush: Invalid emit_callback")
		return
	
	# Emit signals for all pending slices
	for slice_name in _pending_slice_updates:
		var slice_state: Dictionary = _pending_slice_updates[slice_name]
		emit_callback.call(slice_name, slice_state)
	
	# Clear pending updates after flushing
	_pending_slice_updates.clear()

## Get count of pending signals (for debugging/testing)
func get_pending_count() -> int:
	return _pending_slice_updates.size()
