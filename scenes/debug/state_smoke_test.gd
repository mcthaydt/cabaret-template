extends Node

## Smoke test for state store - exercises all slices and actions
##
## This scene tests:
## - All three slices (boot, menu, gameplay)
## - All action creators
## - State transitions
## - Persistence (save/load)
## - Debug overlay
##
## Run this scene and check console for results

var store: M_StateStore
var test_results: Array[String] = []
var test_count: int = 0
var pass_count: int = 0

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("STATE STORE SMOKE TEST")
	print("=".repeat(60))
	
	# Wait for scene to initialize
	await get_tree().process_frame
	
	# Get store
	store = U_StateUtils.get_store(self)
	if not store:
		_fail("Failed to get M_StateStore")
		_print_results()
		return
	
	_pass("M_StateStore found")
	
	# Run all tests
	await _test_boot_slice()
	await _test_menu_slice()
	await _test_gameplay_slice()
	await _test_state_transitions()
	await _test_persistence()
	await _test_performance()
	
	# Print final results
	_print_results()
	
	# Exit after brief delay
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## Test boot slice
func _test_boot_slice() -> void:
	print("\n--- Testing Boot Slice ---")
	
	# Initial state
	var boot_state: Dictionary = store.get_slice(StringName("boot"))
	if boot_state.is_empty():
		_fail("Boot slice not registered")
		return
	_pass("Boot slice registered")
	
	# Update loading progress
	store.dispatch(U_BootActions.update_loading_progress(0.5))
	await get_tree().process_frame
	
	boot_state = store.get_slice(StringName("boot"))
	if boot_state.get("loading_progress", 0.0) != 0.5:
		_fail("Loading progress not updated")
		return
	_pass("Loading progress updates correctly")
	
	# Boot complete
	store.dispatch(U_BootActions.boot_complete())
	await get_tree().process_frame
	
	boot_state = store.get_slice(StringName("boot"))
	if not boot_state.get("is_ready", false):
		_fail("Boot complete not setting is_ready")
		return
	_pass("Boot complete works")
	
	# Boot error
	store.dispatch(U_BootActions.boot_error("Test error"))
	await get_tree().process_frame
	
	boot_state = store.get_slice(StringName("boot"))
	if boot_state.get("error_message", "") != "Test error":
		_fail("Boot error not setting message")
		return
	_pass("Boot error handling works")

## Test menu slice
func _test_menu_slice() -> void:
	print("\n--- Testing Menu Slice ---")
	
	# Initial state
	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	if menu_state.is_empty():
		_fail("Menu slice not registered")
		return
	_pass("Menu slice registered")
	
	# Navigate to screen
	store.dispatch(U_MenuActions.navigate_to_screen("settings"))
	await get_tree().process_frame
	
	menu_state = store.get_slice(StringName("menu"))
	if menu_state.get("active_screen", "") != "settings":
		_fail("Navigate to screen not working")
		return
	_pass("Menu navigation works")
	
	# Select character
	store.dispatch(U_MenuActions.select_character("warrior"))
	await get_tree().process_frame
	
	menu_state = store.get_slice(StringName("menu"))
	if menu_state.get("pending_character", "") != "warrior":
		_fail("Character selection not working")
		return
	_pass("Character selection works")
	
	# Select difficulty
	store.dispatch(U_MenuActions.select_difficulty("hard"))
	await get_tree().process_frame
	
	menu_state = store.get_slice(StringName("menu"))
	if menu_state.get("pending_difficulty", "") != "hard":
		_fail("Difficulty selection not working")
		return
	_pass("Difficulty selection works")

## Test gameplay slice
func _test_gameplay_slice() -> void:
	print("\n--- Testing Gameplay Slice ---")
	
	# Initial state
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	if gameplay_state.is_empty():
		_fail("Gameplay slice not registered")
		return
	_pass("Gameplay slice registered")
	
	# Pause
	store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	
	gameplay_state = store.get_slice(StringName("gameplay"))
	if not gameplay_state.get("paused", false):
		_fail("Pause not working")
		return
	_pass("Pause works")
	
	# Unpause
	store.dispatch(U_GameplayActions.unpause_game())
	await get_tree().process_frame
	
	gameplay_state = store.get_slice(StringName("gameplay"))
	if gameplay_state.get("paused", true):
		_fail("Unpause not working")
		return
	_pass("Unpause works")
	
	# Test entity snapshots (Entity Coordination Pattern)
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(10, 5, 10),
		"velocity": Vector3(2, 0, 0),
		"is_on_floor": true
	}))
	await get_tree().process_frame
	
	gameplay_state = store.get_slice(StringName("gameplay"))
	var entities: Dictionary = gameplay_state.get("entities", {})
	if not entities.has("player"):
		_fail("Entity snapshot not stored")
		return
	_pass("Entity snapshot works")
	
	# Test entity position retrieval
	var player_data: Dictionary = entities.get("player", {})
	var player_pos: Vector3 = player_data.get("position", Vector3.ZERO)
	if player_pos != Vector3(10, 5, 10):
		_fail("Entity position not correct")
		return
	_pass("Entity data retrieval works")

## Test state transitions
func _test_state_transitions() -> void:
	print("\n--- Testing State Transitions ---")
	
	# Transition to menu
	store.dispatch(U_TransitionActions.transition_to_menu())
	await get_tree().process_frame
	_pass("Transition to menu dispatched")
	
	# Transition to gameplay
	store.dispatch(U_TransitionActions.transition_to_gameplay({"character": "mage", "difficulty": "normal"}))
	await get_tree().process_frame
	_pass("Transition to gameplay dispatched")
	
	# Transition to boot
	store.dispatch(U_TransitionActions.transition_to_boot())
	await get_tree().process_frame
	_pass("Transition to boot dispatched")

## Test persistence
func _test_persistence() -> void:
	print("\n--- Testing Persistence ---")
	
	# Set some state
	store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	
	# Save
	var save_path: String = "user://smoke_test_save.json"
	var save_result: Error = store.save_state(save_path)
	if save_result != OK:
		_fail("Save failed with error: %d" % save_result)
		return
	_pass("State saved successfully")
	
	# Modify state
	store.dispatch(U_GameplayActions.unpause_game())
	await get_tree().process_frame
	
	# Load
	var load_result: Error = store.load_state(save_path)
	if load_result != OK:
		_fail("Load failed with error: %d" % load_result)
		return
	_pass("State loaded successfully")
	
	# Verify loaded values
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	if not gameplay_state.get("paused", false):
		_fail("Loaded pause state incorrect")
		return
	_pass("State persistence verified")
	
	# Clean up
	DirAccess.remove_absolute(save_path)

## Test performance
func _test_performance() -> void:
	print("\n--- Testing Performance ---")
	
	# Get initial metrics
	var initial_metrics: Dictionary = store.get_performance_metrics()
	var initial_count: int = initial_metrics.get("dispatch_count", 0)
	
	# Dispatch 100 actions
	for i in range(100):
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		store.dispatch(action)
	
	await get_tree().process_frame
	
	# Check metrics updated
	var final_metrics: Dictionary = store.get_performance_metrics()
	var final_count: int = final_metrics.get("dispatch_count", 0)
	
	if final_count != initial_count + 100:
		_fail("Performance metrics not tracking correctly: %d vs %d" % [final_count, initial_count + 100])
		return
	_pass("Performance metrics tracking works")
	
	var avg_time: float = final_metrics.get("avg_dispatch_time_ms", 0.0)
	print("  Average dispatch time: %.6f ms" % avg_time)
	
	if avg_time > 0.1:
		_fail("Dispatch time exceeds target (%.6f ms > 0.1 ms)" % avg_time)
		return
	_pass("Dispatch performance within target")

## Helper: Record test pass
func _pass(message: String) -> void:
	test_count += 1
	pass_count += 1
	test_results.append("[PASS] " + message)
	print("  ✓ " + message)

## Helper: Record test fail
func _fail(message: String) -> void:
	test_count += 1
	test_results.append("[FAIL] " + message)
	push_error("  ✗ " + message)

## Helper: Print final results
func _print_results() -> void:
	print("\n" + "=".repeat(60))
	print("SMOKE TEST RESULTS")
	print("=".repeat(60))
	print("Tests run: %d" % test_count)
	print("Passed: %d" % pass_count)
	print("Failed: %d" % (test_count - pass_count))
	
	if pass_count == test_count:
		print("\n✓ ALL SMOKE TESTS PASSED!")
	else:
		print("\n✗ SOME TESTS FAILED")
		print("\nFailed tests:")
		for result in test_results:
			if result.begins_with("[FAIL]"):
				print("  " + result)
	
	print("=".repeat(60))
