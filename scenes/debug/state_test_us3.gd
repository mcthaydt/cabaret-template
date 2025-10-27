extends Node

## Test scene for User Story 3 (Boot Slice)
##
## Demonstrates boot sequence with loading progress updates

func _ready() -> void:
	# Wait for store to be ready
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if not store:
		print("[TEST] ERROR: Could not find M_StateStore")
		return
	
	print("[TEST] Boot slice test scene starting...")
	
	# Print initial boot state
	var boot_state: Dictionary = store.get_slice(StringName("boot"))
	print("[TEST] Initial boot state: ", boot_state)
	
	# Simulate loading sequence
	print("[TEST] Simulating loading sequence...")
	await _simulate_loading(store)
	
	print("[TEST] Boot slice test complete!")

func _simulate_loading(store: M_StateStore) -> void:
	# Update loading progress: 0.0 -> 0.25 -> 0.5 -> 0.75 -> 1.0
	var progress_steps := [0.25, 0.5, 0.75, 1.0]
	
	for progress in progress_steps:
		await get_tree().create_timer(0.5).timeout
		store.dispatch(U_BootActions.update_loading_progress(progress))
		
		var boot_state: Dictionary = store.get_slice(StringName("boot"))
		print("[TEST] Loading progress: %.0f%% - Phase: %s" % [progress * 100, boot_state.get("phase")])
	
	# Mark boot complete
	await get_tree().create_timer(0.5).timeout
	store.dispatch(U_BootActions.boot_complete())
	
	var final_state: Dictionary = store.get_slice(StringName("boot"))
	print("[TEST] Boot complete! Is Ready: ", final_state.get("is_ready"))
	print("[TEST] Final boot state: ", final_state)
	
	# Demonstrate error state (optional)
	await get_tree().create_timer(1.0).timeout
	print("[TEST] Testing error state...")
	store.dispatch(U_BootActions.boot_error("Simulated error for testing"))
	
	var error_state: Dictionary = store.get_slice(StringName("boot"))
	print("[TEST] Error state - Phase: %s, Message: %s" % [error_state.get("phase"), error_state.get("error_message")])
