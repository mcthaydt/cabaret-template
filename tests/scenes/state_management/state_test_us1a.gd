extends Node3D

## Test scene for User Story 1a: Core M_StateStore Skeleton
##
## Tests:
## - M_StateStore node exists in scene tree
## - Can access store via U_StateUtils.get_store()
## - Can dispatch actions
## - Subscribers receive callbacks

func _ready() -> void:
	print("\n=== State Test US1a: Core M_StateStore Skeleton ===")
	
	# Wait for tree to be ready
	await get_tree().process_frame
	
	# Test 1: Access store via U_StateUtils
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore via U_StateUtils")
		return
	print("✓ PASS: M_StateStore accessible via U_StateUtils")
	
	# Test 2: Subscribe to state changes
	# Use Array for proper lambda capture (GDScript limitation with Dictionaries)
	var action_received: Array = []
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		action_received.append(action.duplicate())
		print("✓ PASS: Subscriber received action: ", action.get("type"))
	)
	
	# Test 3: Dispatch test action
	var test_action := {
		"type": StringName("test/action"),
		"payload": {"test_value": 123}
	}
	
	# Register test action to avoid validation errors
	U_ActionRegistry.register_action(StringName("test/action"), {})
	
	store.dispatch(test_action)
	
	# Verify dispatch worked
	if action_received.is_empty():
		push_error("FAIL: Subscriber did not receive action")
	else:
		print("✓ PASS: Action dispatched successfully")
		print("  Received action type: ", action_received[0].get("type"))
	
	# Test 4: Get state
	var state := store.get_state()
	print("✓ PASS: Retrieved state: ", state)
	
	# Cleanup
	unsubscribe.call()
	
	print("=== US1a Tests Complete ===\n")
