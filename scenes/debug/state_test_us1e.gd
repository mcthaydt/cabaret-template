extends Node3D

## Test scene for User Story 1e: Selector System with Dependencies
##
## Tests:
## - Selectors compute derived state correctly
## - get_is_player_alive works based on health
## - get_is_game_over computes from objectives
## - get_completion_percentage calculates progress

func _ready() -> void:
	print("\n=== State Test US1e: Selector System ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	print("Initial state:", store.get_state())
	
	# Test 1: get_is_player_alive with default health (100)
	print("\nTest 1: get_is_player_alive with health=100")
	var gameplay_state := store.get_slice(StringName("gameplay"))
	var is_alive: bool = GameplaySelectors.get_is_player_alive(gameplay_state)
	print("is_alive =", is_alive)
	
	if is_alive:
		print("✓ PASS: Player is alive with health > 0")
	else:
		push_error("FAIL: Player should be alive with health=100")
	
	# Test 2: Set health to 0 and check is_player_alive
	print("\nTest 2: Set health to 0")
	store.dispatch(U_GameplayActions.update_health(0))
	await get_tree().physics_frame
	
	gameplay_state = store.get_slice(StringName("gameplay"))
	is_alive = GameplaySelectors.get_is_player_alive(gameplay_state)
	print("After health=0, is_alive =", is_alive)
	
	if not is_alive:
		print("✓ PASS: Player is not alive with health=0")
	else:
		push_error("FAIL: Player should not be alive with health=0")
	
	# Test 3: Restore health and verify alive again
	print("\nTest 3: Restore health to 50")
	store.dispatch(U_GameplayActions.update_health(50))
	await get_tree().physics_frame
	
	gameplay_state = store.get_slice(StringName("gameplay"))
	is_alive = GameplaySelectors.get_is_player_alive(gameplay_state)
	var health: int = gameplay_state.get("health", 0)
	print("After health=50, is_alive =", is_alive, ", health =", health)
	
	if is_alive and health == 50:
		print("✓ PASS: Player alive again after restoring health")
	else:
		push_error("FAIL: Player should be alive with health=50")
	
	# Test 4: get_is_game_over (no objectives, should be false)
	print("\nTest 4: get_is_game_over (no objectives)")
	var game_over: bool = GameplaySelectors.get_is_game_over(gameplay_state)
	print("game_over =", game_over)
	
	if not game_over:
		print("✓ PASS: Game not over when no objectives present")
	else:
		push_error("FAIL: Game should not be over without objectives")
	
	# Test 5: get_completion_percentage (no objectives, should be 0.0)
	print("\nTest 5: get_completion_percentage (no objectives)")
	var completion: float = GameplaySelectors.get_completion_percentage(gameplay_state)
	print("completion_percentage =", completion, "%")
	
	if completion == 0.0:
		print("✓ PASS: Completion is 0% when no objectives present")
	else:
		push_error("FAIL: Completion should be 0% without objectives")
	
	# Test 6: Verify selectors are pure (calling twice with same state)
	print("\nTest 6: Verify selectors are pure functions")
	var first_call := GameplaySelectors.get_is_player_alive(gameplay_state)
	var second_call := GameplaySelectors.get_is_player_alive(gameplay_state)
	
	if first_call == second_call:
		print("✓ PASS: Selector is pure (same input -> same output)")
	else:
		push_error("FAIL: Selector should be deterministic")
	
	print("\nFinal gameplay state:", gameplay_state)
	print("=== US1e Tests Complete ===\n")
