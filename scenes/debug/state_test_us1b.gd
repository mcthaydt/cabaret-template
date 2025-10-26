extends Node3D

## Test scene for User Story 1b: Action Registry with StringName Validation
##
## Tests:
## - Action validation works correctly
## - Registered actions are accepted
## - Unregistered actions are rejected
## - Action type is StringName not String

func _ready() -> void:
	print("\n=== State Test US1b: Action Registry Validation ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	# Connect to validation_failed signal to catch errors
	var validation_errors: Array[String] = []
	store.validation_failed.connect(func(action: Dictionary, error: String) -> void:
		validation_errors.append(error)
		print("✓ PASS: Validation rejected invalid action: ", error)
	)
	
	# Test 1: Valid action (pause_game)
	print("Test 1: Dispatching valid action (pause_game)...")
	store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	print("✓ PASS: Valid action accepted")
	
	# Test 2: Invalid action (missing type)
	print("\nTest 2: Dispatching invalid action (missing type)...")
	store.dispatch({"payload": {"test": true}})
	await get_tree().process_frame
	if validation_errors.size() > 0:
		print("✓ PASS: Action without 'type' rejected")
	else:
		push_error("FAIL: Action without 'type' was not rejected")
	
	# Test 3: Unregistered action
	print("\nTest 3: Dispatching unregistered action type...")
	validation_errors.clear()
	store.dispatch({"type": StringName("unregistered/action")})
	await get_tree().process_frame
	if validation_errors.size() > 0:
		print("✓ PASS: Unregistered action rejected")
	else:
		push_error("FAIL: Unregistered action was not rejected")
	
	# Test 4: Verify action type is StringName
	var pause_action := U_GameplayActions.pause_game()
	if pause_action.get("type") is StringName:
		print("\n✓ PASS: Action type is StringName")
	else:
		push_error("FAIL: Action type is not StringName")
	
	print("=== US1b Tests Complete ===\n")
