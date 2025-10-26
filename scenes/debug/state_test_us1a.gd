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
	var action_received: Dictionary = {}
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		action_received = action.duplicate()
		print("✓ PASS: Subscriber received action: ", action.get("type"))
	)
	
	print("Subscriber registered, unsubscribe callable valid:", unsubscribe.is_valid())
	
	# Test 3: Dispatch test action
	var test_action := {
		"type": StringName("test/action"),
		"payload": {"test_value": 123}
	}
	
	# Register test action to avoid validation errors
	ActionRegistry.register_action(StringName("test/action"), {})
	print("Action registered, is_registered:", ActionRegistry.is_registered(StringName("test/action")))
	
	# Connect to validation_failed signal to see if validation fails
	store.validation_failed.connect(func(action: Dictionary, error: String) -> void:
		push_error("Action validation failed: ", error)
	)
	
	print("Dispatching action:", test_action)
	store.dispatch(test_action)
	print("After dispatch, action_received:", action_received)
	
	# Verify dispatch worked
	if action_received.is_empty():
		push_error("FAIL: Subscriber did not receive action")
	else:
		print("✓ PASS: Action dispatched successfully")
	
	# Test 4: Get state
	var state := store.get_state()
	print("✓ PASS: Retrieved state: ", state)
	
	# Cleanup
	unsubscribe.call()
	
	print("=== US1a Tests Complete ===\n")
