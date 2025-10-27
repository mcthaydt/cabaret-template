extends ECSSystem
class_name S_PauseSystem

## Pause System - Manages game pause state via State Store
##
## Handles ESC key to toggle pause, reads pause state from store,
## emits signals for other systems to react to pause changes.

signal pause_state_changed(is_paused: bool)

var _store: M_StateStore = null
var _is_paused: bool = false

func _ready() -> void:
	super._ready()
	
	# Get reference to state store
	_store = U_StateUtils.get_store(self)
	
	if not _store:
		push_error("S_PauseSystem: Could not find M_StateStore")
		return
	
	# Subscribe to gameplay slice updates
	_store.slice_updated.connect(_on_slice_updated)
	
	# Read initial pause state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	_is_paused = GameplaySelectors.get_is_paused(gameplay_state)

func _exit_tree() -> void:
	# Clean up subscriptions
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	super._exit_tree()

func _unhandled_input(event: InputEvent) -> void:
	if not _store:
		return
	
	# Check for ESC key press (pause toggle)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			toggle_pause()
			get_viewport().set_input_as_handled()

## Toggle pause state via state store
func toggle_pause() -> void:
	if not _store:
		return
	
	# Get current pause state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	var is_currently_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	# Dispatch opposite action
	if is_currently_paused:
		_store.dispatch(U_GameplayActions.unpause_game())
	else:
		_store.dispatch(U_GameplayActions.pause_game())

## Handle state store slice updates
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	
	var new_paused: bool = GameplaySelectors.get_is_paused(slice_state)
	
	# Only emit if state changed
	if new_paused != _is_paused:
		_is_paused = new_paused
		pause_state_changed.emit(_is_paused)
		
		# Log pause state change
		if _is_paused:
			print("[PAUSE] Game paused")
		else:
			print("[PAUSE] Game unpaused")

## Check if game is currently paused (for other systems)
func is_paused() -> bool:
	return _is_paused
