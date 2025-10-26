extends RefCounted
class_name StateHandoff

## StateHandoff preserves state across scene changes without autoloads.
##
## M_StateStore uses this on _exit_tree/_ready to maintain state when changing scenes.
## This is a static utility class - no instance creation needed.
##
## Usage:
##   # Before scene change (in _exit_tree):
##   StateHandoff.preserve_slice(StringName("gameplay"), gameplay_state)
##
##   # After scene loads (in _ready):
##   var restored := StateHandoff.restore_slice(StringName("gameplay"))
##   if not restored.is_empty():
##       # Merge restored state with initial state

## Static storage for preserved slices (slice_name -> slice_state)
static var _preserved_slices: Dictionary = {}

## Preserve a slice's state for the next scene
##
## Stores a deep copy of the slice state. Call this in M_StateStore._exit_tree()
## before changing scenes.
static func preserve_slice(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name == StringName():
		push_warning("StateHandoff.preserve_slice: Empty slice name")
		return
	
	# Store deep copy to prevent external modifications
	_preserved_slices[slice_name] = slice_state.duplicate(true)

## Restore a previously preserved slice's state
##
## Returns the preserved state as a deep copy, or an empty dictionary if
## the slice was never preserved. Call this in M_StateStore._ready() after
## a scene change.
static func restore_slice(slice_name: StringName) -> Dictionary:
	if slice_name == StringName():
		return {}
	
	if not _preserved_slices.has(slice_name):
		return {}
	
	# Return deep copy to prevent external modifications
	return _preserved_slices[slice_name].duplicate(true)

## Clear a specific preserved slice
##
## Removes the slice from preserved state. Useful for cleanup after
## the state has been restored.
static func clear_slice(slice_name: StringName) -> void:
	_preserved_slices.erase(slice_name)

## Clear all preserved slices
##
## Removes all preserved state. Useful for starting fresh or cleanup.
static func clear_all() -> void:
	_preserved_slices.clear()
