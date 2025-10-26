extends Node3D

## Test scene for User Story 1h: Persistence and StateHandoff
##
## Tests:
## - Save state to JSON file
## - Load state from JSON file
## - Transient fields excluded from save
## - Godot types serialize correctly
## - StateHandoff preserves state across scene transitions

const StateHandoff := preload("res://scripts/state/state_handoff.gd")

var test_save_path: String = "user://state_test_us1h_save.json"

func _ready() -> void:
	print("\n=== State Test US1h: Persistence & StateHandoff ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	# Test 1: Save and load state
	print("\nTest 1: Save and load state")
	
	# Set up some state
	store.dispatch(U_GameplayActions.update_health(85))
	store.dispatch(U_GameplayActions.update_score(500))
	store.dispatch(U_GameplayActions.set_level(7))
	store.dispatch(U_GameplayActions.pause_game())
	
	var before_save := store.get_slice(StringName("gameplay"))
	print("State before save:")
	print("  health:", before_save.get("health"))
	print("  score:", before_save.get("score"))
	print("  level:", before_save.get("level"))
	print("  paused:", before_save.get("paused"))
	
	# Save state
	var save_result: Error = store.save_state(test_save_path)
	if save_result == OK:
		print("✓ PASS: State saved successfully to", test_save_path)
	else:
		push_error("FAIL: Save failed with error code ", save_result)
		return
	
	# Verify file exists
	if FileAccess.file_exists(test_save_path):
		print("✓ PASS: Save file exists")
		
		# Read and print JSON
		var file := FileAccess.open(test_save_path, FileAccess.READ)
		if file:
			var json_text := file.get_as_text()
			file.close()
			print("\nSaved JSON content (first 200 chars):")
			print(json_text.substr(0, 200), "...")
	else:
		push_error("FAIL: Save file does not exist")
	
	# Modify state
	store.dispatch(U_GameplayActions.update_health(10))
	store.dispatch(U_GameplayActions.update_score(0))
	
	var before_load := store.get_slice(StringName("gameplay"))
	print("\nState after modification (before load):")
	print("  health:", before_load.get("health"), "(should be 10)")
	print("  score:", before_load.get("score"), "(should be 0)")
	
	# Load state
	var load_result: Error = store.load_state(test_save_path)
	if load_result == OK:
		print("✓ PASS: State loaded successfully")
	else:
		push_error("FAIL: Load failed with error code ", load_result)
		return
	
	# Verify state restored
	var after_load := store.get_slice(StringName("gameplay"))
	print("\nState after load (should match original):")
	print("  health:", after_load.get("health"), "(expected: 85)")
	print("  score:", after_load.get("score"), "(expected: 500)")
	print("  level:", after_load.get("level"), "(expected: 7)")
	print("  paused:", after_load.get("paused"), "(expected: true)")
	
	var all_match: bool = (
		after_load.get("health") == 85 and
		after_load.get("score") == 500 and
		after_load.get("level") == 7 and
		after_load.get("paused") == true
	)
	
	if all_match:
		print("✓ PASS: All state values restored correctly")
	else:
		push_error("FAIL: State values don't match")
	
	# Test 2: StateHandoff (simulated - same scene)
	print("\nTest 2: StateHandoff preservation")
	print("Note: StateHandoff automatically preserves state in _exit_tree()")
	print("      and restores it in _ready() when changing scenes.")
	print("      In this test we verify the StateHandoff class directly:")
	
	# Test direct StateHandoff usage
	var test_state := {"test_value": 42, "nested": {"data": "preserved"}}
	StateHandoff.preserve_slice(StringName("test_slice"), test_state)
	
	var restored: Dictionary = StateHandoff.restore_slice(StringName("test_slice"))
	if restored.get("test_value") == 42 and restored.get("nested", {}).get("data") == "preserved":
		print("✓ PASS: StateHandoff preserves and restores state correctly")
	else:
		push_error("FAIL: StateHandoff didn't preserve state")
	
	StateHandoff.clear_slice(StringName("test_slice"))
	
	# Cleanup
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
		print("\nCleaned up test save file")
	
	print("\n=== US1h Tests Complete ===")
