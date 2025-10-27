extends Node

## Debug script to monitor pause state
## Add this to the scene temporarily to see what's happening

var _store: M_StateStore = null

func _ready() -> void:
	await get_tree().process_frame
	_store = U_StateUtils.get_store(self)
	
	if not _store:
		print("[DEBUG] ERROR: Could not find M_StateStore!")
		return
	
	print("[DEBUG] Found M_StateStore, subscribing to state changes...")
	
	# Subscribe to all actions (subscribers receive action and state)
	_store.subscribe(_on_action_dispatched)
	
	# Subscribe to slice updates
	_store.slice_updated.connect(_on_slice_updated)
	
	# Subscribe to action_dispatched signal (this gives us the action)
	_store.action_dispatched.connect(_on_action_signal)
	
	# Print initial state
	var state: Dictionary = _store.get_slice(StringName("gameplay"))
	print("[DEBUG] Initial pause state: ", GameplaySelectors.get_is_paused(state))

func _on_action_dispatched(action: Dictionary, state: Dictionary) -> void:
	# Subscribers receive action and full state
	var gameplay_state: Dictionary = state.get("gameplay", {})
	print("[DEBUG] Action dispatched: ", action.get("type"), " -> Pause state now: ", GameplaySelectors.get_is_paused(gameplay_state))

func _on_action_signal(action: Dictionary) -> void:
	print("[DEBUG] Action signal: ", action.get("type"))

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name == StringName("gameplay"):
		print("[DEBUG] Gameplay slice updated - paused: ", GameplaySelectors.get_is_paused(slice_state))

func _input(event: InputEvent) -> void:
	# Use _input instead of _unhandled_input to catch it before systems
	if event.is_action_pressed("pause"):
		print("[DEBUG] 'pause' input action detected!")
