extends Node3D

## Test scene for User Story 1d: Type-Safe Action Creators
##
## Tests:
## - update_health action updates state correctly
## - update_score action updates state correctly
## - set_level action updates state correctly
## - All actions return typed Dictionary

func _ready() -> void:
	print("\n=== State Test US1d: Type-Safe Action Creators ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	# Test 1: update_health
	print("Test 1: Dispatching update_health(75)...")
	store.dispatch(U_GameplayActions.update_health(75))
	await get_tree().physics_frame
	
	var state_after_health := store.get_slice(StringName("gameplay"))
	var health: int = state_after_health.get("health", 0)
	print("Health after update: ", health)
	
	if health == 75:
		print("✓ PASS: update_health action worked correctly")
	else:
		push_error("FAIL: update_health did not update state (expected 75, got ", health, ")")
	
	# Test 2: update_score
	print("\nTest 2: Dispatching update_score(1000)...")
	store.dispatch(U_GameplayActions.update_score(1000))
	await get_tree().physics_frame
	
	var state_after_score := store.get_slice(StringName("gameplay"))
	var score: int = state_after_score.get("score", 0)
	print("Score after update: ", score)
	
	if score == 1000:
		print("✓ PASS: update_score action worked correctly")
	else:
		push_error("FAIL: update_score did not update state (expected 1000, got ", score, ")")
	
	# Test 3: set_level
	print("\nTest 3: Dispatching set_level(5)...")
	store.dispatch(U_GameplayActions.set_level(5))
	await get_tree().physics_frame
	
	var state_after_level := store.get_slice(StringName("gameplay"))
	var level: int = state_after_level.get("level", 0)
	print("Level after update: ", level)
	
	if level == 5:
		print("✓ PASS: set_level action worked correctly")
	else:
		push_error("FAIL: set_level did not update state (expected 5, got ", level, ")")
	
	# Test 4: Verify action creators return Dictionary
	var health_action: Variant = U_GameplayActions.update_health(50)
	var score_action: Variant = U_GameplayActions.update_score(500)
	var level_action: Variant = U_GameplayActions.set_level(3)
	
	if health_action is Dictionary and score_action is Dictionary and level_action is Dictionary:
		print("\n✓ PASS: All action creators return Dictionary type")
	else:
		push_error("FAIL: Action creators do not return Dictionary")
	
	# Final state
	var final_state := store.get_slice(StringName("gameplay"))
	print("\nFinal gameplay state: ", final_state)
	
	print("=== US1d Tests Complete ===\n")
