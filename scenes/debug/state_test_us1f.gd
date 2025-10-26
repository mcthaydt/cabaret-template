extends Node3D

## Test scene for User Story 1f: Signal Batching
##
## Tests:
## - Multiple dispatches in single frame emit only one signal per slice
## - State updates are immediate (synchronous)
## - Signal emissions are batched (per physics frame)

var slice_updated_count: int = 0

func _ready() -> void:
	print("\n=== State Test US1f: Signal Batching ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	# Connect to slice_updated signal to count emissions
	store.slice_updated.connect(_on_slice_updated)
	
	print("Test 1: Dispatch 10 actions in single frame")
	print("Expectation: Only 1 slice_updated signal emitted despite 10 dispatches")
	
	# Reset counter
	slice_updated_count = 0
	
	# Dispatch 10 actions rapidly (same frame)
	for i in range(10):
		store.dispatch(U_GameplayActions.update_health(100 - i))
	
	# Verify state updates are immediate (synchronous)
	var immediate_state := store.get_slice(StringName("gameplay"))
	var immediate_health: int = immediate_state.get("health", 100)
	
	print("\nImmediate read after 10 dispatches:")
	print("  health =", immediate_health, "(expected: 91)")
	
	if immediate_health == 91:
		print("✓ PASS: State updates are immediate (synchronous)")
	else:
		push_error("FAIL: State should update immediately, got health=", immediate_health)
	
	print("\nSignal emissions counted so far:", slice_updated_count)
	print("Waiting for physics frame to flush batched signals...")
	
	# Wait for physics frame to flush batched signals
	await get_tree().physics_frame
	
	print("After physics frame, signal emissions:", slice_updated_count)
	
	# Should only have 1 signal emission despite 10 dispatches
	if slice_updated_count == 1:
		print("✓ PASS: Only 1 signal emitted for 10 dispatches (batching works)")
	else:
		push_error("FAIL: Expected 1 signal, got ", slice_updated_count)
	
	# Test 2: Dispatch more actions in new frame
	print("\nTest 2: Dispatch 5 more actions in new frame")
	slice_updated_count = 0
	
	for i in range(5):
		store.dispatch(U_GameplayActions.update_score(i * 100))
	
	await get_tree().physics_frame
	
	print("Signal emissions after 5 more dispatches:", slice_updated_count)
	
	if slice_updated_count == 1:
		print("✓ PASS: Batching continues to work in subsequent frames")
	else:
		push_error("FAIL: Expected 1 signal, got ", slice_updated_count)
	
	# Test 3: Verify final state
	var final_state := store.get_slice(StringName("gameplay"))
	var final_health: int = final_state.get("health", 0)
	var final_score: int = final_state.get("score", 0)
	
	print("\nFinal state:")
	print("  health =", final_health)
	print("  score =", final_score)
	
	if final_health == 91 and final_score == 400:
		print("✓ PASS: All state updates applied correctly")
	else:
		push_error("FAIL: State mismatch - health=", final_health, " score=", final_score)
	
	print("=== US1f Tests Complete ===\n")
	
	# Disconnect to avoid memory leaks
	store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	slice_updated_count += 1
	print("  [SIGNAL] slice_updated emitted for '", slice_name, "' (count: ", slice_updated_count, ")")
