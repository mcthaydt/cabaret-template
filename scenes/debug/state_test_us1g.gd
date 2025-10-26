extends Node3D

## Test scene for User Story 1g: Action History with 1000-Entry Circular Buffer
##
## Tests:
## - Action history records actions with timestamps
## - get_last_n_actions() returns correct count
## - Circular buffer prunes oldest entries when exceeding max size
## - History includes state_after snapshots

func _ready() -> void:
	print("\n=== State Test US1g: Action History ===")
	
	await get_tree().process_frame
	
	var store := U_StateUtils.get_store(self)
	if store == null:
		push_error("FAIL: Could not access M_StateStore")
		return
	
	print("Test 1: Action history records with timestamps and state snapshots")
	
	# Dispatch a few actions
	store.dispatch(U_GameplayActions.pause_game())
	store.dispatch(U_GameplayActions.update_health(75))
	store.dispatch(U_GameplayActions.update_score(100))
	store.dispatch(U_GameplayActions.update_score(250))
	store.dispatch(U_GameplayActions.unpause_game())
	
	var history: Array = store.get_action_history()
	print("\nHistory size after 5 actions:", history.size())
	
	if history.size() == 5:
		print("✓ PASS: History contains all 5 actions")
	else:
		push_error("FAIL: Expected 5 history entries, got ", history.size())
	
	# Check first entry structure
	print("\nFirst history entry structure:")
	var first_entry: Dictionary = history[0]
	print("  has 'action':", first_entry.has("action"))
	print("  has 'timestamp':", first_entry.has("timestamp"))
	print("  has 'state_after':", first_entry.has("state_after"))
	
	if first_entry.has("action") and first_entry.has("timestamp") and first_entry.has("state_after"):
		print("✓ PASS: History entry has required fields")
		
		# Check action type
		var action_type: StringName = first_entry["action"].get("type", StringName())
		print("  action type:", action_type)
		
		# Check timestamp is a number
		var timestamp: Variant = first_entry["timestamp"]
		if timestamp is float or timestamp is int:
			print("  timestamp:", timestamp, "seconds")
			print("✓ PASS: Timestamp is a number")
		else:
			push_error("FAIL: Timestamp should be a number, got ", typeof(timestamp))
		
		# Check state_after
		var state_after: Dictionary = first_entry["state_after"]
		if state_after.has("gameplay"):
			print("  state_after has gameplay slice")
			var gameplay: Dictionary = state_after["gameplay"]
			print("    paused:", gameplay.get("paused", false))
			print("    health:", gameplay.get("health", 0))
			print("    score:", gameplay.get("score", 0))
			print("✓ PASS: state_after contains gameplay state snapshot")
		else:
			push_error("FAIL: state_after should have gameplay slice")
	else:
		push_error("FAIL: History entry missing required fields")
	
	# Test 2: get_last_n_actions()
	print("\nTest 2: get_last_n_actions() returns correct count")
	
	var last_3: Array = store.get_last_n_actions(3)
	print("Last 3 actions count:", last_3.size())
	
	if last_3.size() == 3:
		print("✓ PASS: get_last_n_actions(3) returned 3 entries")
		
		# Verify they are the most recent
		var last_entry: Dictionary = last_3[last_3.size() - 1]
		var last_action_type: StringName = last_entry["action"].get("type", StringName())
		print("  Last action type:", last_action_type)
		
		if last_action_type == U_GameplayActions.ACTION_UNPAUSE_GAME:
			print("✓ PASS: Last action is unpause (most recent)")
		else:
			push_error("FAIL: Last action should be unpause, got ", last_action_type)
	else:
		push_error("FAIL: Expected 3 entries, got ", last_3.size())
	
	# Test 3: Requesting more than available
	var last_20: Array = store.get_last_n_actions(20)
	print("\nRequesting last 20 (only 5 exist):", last_20.size())
	
	if last_20.size() == 5:
		print("✓ PASS: Returned all 5 available entries")
	else:
		push_error("FAIL: Should return 5 entries, got ", last_20.size())
	
	# Test 4: Verify state evolution in history
	print("\nTest 4: History captures state evolution")
	print("\nState progression:")
	for i in range(history.size()):
		var entry: Dictionary = history[i]
		var action: Dictionary = entry["action"]
		var state: Dictionary = entry["state_after"]["gameplay"]
		var action_type: String = String(action.get("type", ""))
		# Extract just the last part after the slash
		var short_type: String = action_type.split("/")[-1] if "/" in action_type else action_type
		print("  [%d] %s → health=%d score=%d paused=%s" % [
			i, short_type, state.get("health", 0), state.get("score", 0), state.get("paused", false)
		])
	
	# Verify final state matches history
	var current_state: Dictionary = store.get_slice(StringName("gameplay"))
	var last_history_state: Dictionary = history[history.size() - 1]["state_after"]["gameplay"]
	
	if current_state.get("health") == last_history_state.get("health") and \
	   current_state.get("score") == last_history_state.get("score") and \
	   current_state.get("paused") == last_history_state.get("paused"):
		print("✓ PASS: Current state matches last history entry")
	else:
		push_error("FAIL: Current state doesn't match history")
	
	print("\n=== US1g Tests Complete ===\n")
	print("Note: Circular buffer pruning is tested in unit tests with custom max_history_size.")
	print("Default max_history_size is 1000, so pruning won't occur in this short test.")
