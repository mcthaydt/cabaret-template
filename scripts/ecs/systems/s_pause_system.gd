extends ECSSystem
class_name S_PauseSystem

## Pause System - Manages game pause state via State Store
##
## Handles "pause" input action to toggle pause, reads pause state from store,
## emits signals for other systems to react to pause changes.
##
## When pausing, also unlocks cursor for UI interaction.
## When unpausing, locks cursor for gameplay.
##
## Requires "pause" input action in Project Settings → Input Map.

signal pause_state_changed(is_paused: bool)

var _store: M_StateStore = null
var _cursor_manager: M_CursorManager = null
var _is_paused: bool = false

func _ready() -> void:
	super._ready()
	
	# Wait for tree to be fully ready (M_StateStore needs to add itself to group)
	await get_tree().process_frame
	
	# Get reference to state store
	_store = U_StateUtils.get_store(self)
	
	if not _store:
		push_error("S_PauseSystem: Could not find M_StateStore")
		return
	
	# Get reference to cursor manager (optional - pause still works without it)
	var cursor_managers: Array[Node] = get_tree().get_nodes_in_group("cursor_manager")
	if cursor_managers.size() > 0:
		_cursor_manager = cursor_managers[0] as M_CursorManager
	
	# Subscribe to gameplay slice updates
	_store.slice_updated.connect(_on_slice_updated)
	
	# Read initial pause state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	_is_paused = GameplaySelectors.get_is_paused(gameplay_state)

func _exit_tree() -> void:
	# Clean up subscriptions
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _input(event: InputEvent) -> void:
	if not _store:
		return
	
	# Check for "pause" input action (toggle pause + cursor management)
	# Uses _input() instead of _unhandled_input() to process before M_CursorManager
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

## Toggle pause state via state store
func toggle_pause() -> void:
	if not _store:
		return
	
	# Get current pause state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	var is_currently_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	# Dispatch opposite action and update cursor
	if is_currently_paused:
		# Unpause: lock cursor for gameplay
		_store.dispatch(U_GameplayActions.unpause_game())
		if _cursor_manager:
			_cursor_manager.set_cursor_state(true, false)  # locked, hidden
	else:
		# Pause: unlock cursor for UI interaction
		_store.dispatch(U_GameplayActions.pause_game())
		if _cursor_manager:
			_cursor_manager.set_cursor_state(false, true)  # unlocked, visible

## Handle state store slice updates
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	
	var new_paused: bool = GameplaySelectors.get_is_paused(slice_state)
	
	# Only emit if state changed
	if new_paused != _is_paused:
		_is_paused = new_paused
		pause_state_changed.emit(_is_paused)

## Check if game is currently paused (for other systems)
func is_paused() -> bool:
	return _is_paused
