extends Node3D

## Test scene for User Story 1c: Gameplay Slice Reducer Infrastructure
##
## Tests:
## - Reducers process actions correctly
## - State updates are immutable
## - Initial state loads from resource
## - Pause/unpause toggle correctly

func _ready() -> void:
	print("\n=== State Test US1c: Gameplay Slice Reducers ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	# Test 1: Initial state from resource
	var initial_state := store.get_slice(StringName("gameplay"))
	print("Initial state: ", initial_state)
	if initial_state.has("paused"):
		print("✓ PASS: Initial state loaded from resource")
	else:
		push_error("FAIL: Initial state not loaded correctly")
		return
	
	# Test 2: Dispatch pause action
	var state_before_pause := store.get_slice(StringName("gameplay"))
	var paused_before: bool = state_before_pause.get("paused", false)
	
	print("\nTest 2: Dispatching pause action...")
	print("State before pause: paused=", paused_before)
	store.dispatch(U_GameplayActions.pause_game())
	
	await get_tree().physics_frame  # Wait for signal batching
	
	var state_after_pause := store.get_slice(StringName("gameplay"))
	var paused_after: bool = state_after_pause.get("paused", false)
	print("State after pause: paused=", paused_after)
	
	if paused_after == true:
		print("✓ PASS: Pause action updated state correctly")
	else:
		push_error("FAIL: Pause action did not update state")
	
	# Test 3: Verify immutability (old state unchanged)
	if state_before_pause.get("paused") == paused_before:
		print("✓ PASS: Old state was not mutated")
	else:
		push_error("FAIL: Old state was mutated (immutability violated)")
	
	# Test 4: Dispatch unpause action
	print("\nTest 4: Dispatching unpause action...")
	store.dispatch(U_GameplayActions.unpause_game())
	await get_tree().physics_frame
	
	var state_after_unpause := store.get_slice(StringName("gameplay"))
	var paused_final: bool = state_after_unpause.get("paused", true)
	print("State after unpause: paused=", paused_final)
	
	if paused_final == false:
		print("✓ PASS: Unpause action updated state correctly")
	else:
		push_error("FAIL: Unpause action did not update state")
	
	print("=== US1c Tests Complete ===\n")
