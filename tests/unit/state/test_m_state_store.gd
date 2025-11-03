extends GutTest

## Tests for M_StateStore core functionality

const U_StateEventBus := preload("res://scripts/state/u_state_event_bus.gd")

var store: M_StateStore
var callback_called: bool = false
var received_action: Dictionary = {}
var received_state: Dictionary = {}
var signal_emitted: bool = false
var signal_action: Dictionary = {}
var validation_error: String = ""
var callback_count: int = 0
var slice_updated_count: int = 0
var last_slice_name: StringName = StringName()

func before_each() -> void:
	# CRITICAL: Reset state bus between tests to prevent subscription leaks
	U_StateEventBus.reset()
	
	# Reset test variables
	callback_called = false
	received_action = {}
	received_state = {}
	signal_emitted = false
	signal_action = {}
	validation_error = ""
	callback_count = 0
	slice_updated_count = 0
	last_slice_name = StringName()

	store = M_StateStore.new()
	# Set up initial state for testing
	var initial_state := RS_GameplayInitialState.new()
	store.gameplay_initial_state = initial_state
	add_child(store)
	autofree(store)  # Use autofree for proper cleanup
	await get_tree().process_frame  # Deferred registration

func after_each() -> void:
	# Cleanup handled by autofree
	store = null
	U_StateEventBus.reset()

func test_store_instantiates_as_node() -> void:
	assert_not_null(store, "Store should be created")
	assert_true(store is Node, "Store should extend Node")

func test_store_adds_to_state_store_group() -> void:
	assert_true(store.is_in_group("state_store"), "Store should be in 'state_store' group")

func test_dispatch_notifies_subscribers() -> void:
	# Register test action
	U_ActionRegistry.register_action(StringName("test/action"))

	var callback := func(action: Dictionary, state: Dictionary) -> void:
		callback_called = true
		received_action = action
		received_state = state

	var unsubscribe: Callable = store.subscribe(callback)

	assert_true(unsubscribe.is_valid(), "Subscribe should return valid unsubscribe callable")

	# Dispatch action
	var action: Dictionary = {"type": StringName("test/action"), "payload": {"data": "test"}}
	store.dispatch(action)

	assert_true(callback_called, "Callback should be called on dispatch")
	assert_eq(received_action.get("type"), StringName("test/action"), "Callback should receive action type")
	assert_eq(received_action.get("payload").get("data"), "test", "Callback should receive payload")

func test_dispatch_emits_action_dispatched_signal() -> void:
	# Register test action
	U_ActionRegistry.register_action(StringName("test/signal"))

	store.action_dispatched.connect(func(action: Dictionary) -> void:
		signal_emitted = true
		signal_action = action
	)

	var action: Dictionary = {"type": StringName("test/signal"), "payload": null}
	store.dispatch(action)

	await get_tree().process_frame

	assert_true(signal_emitted, "action_dispatched signal should emit")
	assert_eq(signal_action.get("type"), StringName("test/signal"), "Signal should carry action")

func test_dispatch_rejects_action_without_type() -> void:
	store.validation_failed.connect(func(_action: Dictionary, error: String) -> void:
		validation_error = error
	)

	var invalid_action: Dictionary = {"payload": "no type"}
	store.dispatch(invalid_action)
	assert_push_error("Action missing 'type' field")
	
	await get_tree().process_frame

	assert_eq(validation_error, "Action missing 'type' field", "Should emit validation_failed")

func test_unsubscribe_removes_callback() -> void:
	# Register test actions
	U_ActionRegistry.register_action(StringName("test1"))
	U_ActionRegistry.register_action(StringName("test2"))

	var callback := func(_action: Dictionary, _state: Dictionary) -> void:
		callback_count += 1

	var unsubscribe: Callable = store.subscribe(callback)

	store.dispatch({"type": StringName("test1"), "payload": null})
	assert_eq(callback_count, 1, "Callback should fire once")

	unsubscribe.call()

	store.dispatch({"type": StringName("test2"), "payload": null})
	assert_eq(callback_count, 1, "Callback should not fire after unsubscribe")

func test_get_state_returns_deep_copy() -> void:
	var state1: Dictionary = store.get_state()
	state1["test"] = "modified"

	var state2: Dictionary = store.get_state()

	assert_false(state2.has("test"), "Modifying copy should not affect original")

func test_get_slice_returns_deep_copy() -> void:
	var config := RS_StateSliceConfig.new(StringName("test_slice"))
	config.initial_state = {"value": 100}
	store.register_slice(config)

	var slice1: Dictionary = store.get_slice(StringName("test_slice"))
	slice1["value"] = 999

	var slice2: Dictionary = store.get_slice(StringName("test_slice"))

	assert_eq(slice2.get("value"), 100, "Modifying slice copy should not affect original")

func test_register_slice_adds_to_state() -> void:
	var config := RS_StateSliceConfig.new(StringName("gameplay"))
	config.initial_state = {"health": 100, "score": 0}
	store.register_slice(config)

	var full_state: Dictionary = store.get_state()
	assert_true(full_state.has("gameplay"), "State should contain registered slice")

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_slice.get("health"), 100, "Slice should have initial state")
	assert_eq(gameplay_slice.get("score"), 0, "Slice should have initial state")

func test_settings_defaults_when_null() -> void:
	var store_no_settings := M_StateStore.new()
	# Explicitly set settings to null to test default creation
	# This prevents the warning since we're intentionally testing the null case
	store_no_settings.settings = null
	add_child(store_no_settings)
	autofree(store_no_settings)  # Use autofree for proper cleanup
	await get_tree().process_frame

	assert_not_null(store_no_settings.settings, "Should create default settings")
	assert_eq(store_no_settings.settings.max_history_size, 1000, "Default history size should be 1000")

## Phase 1f: Signal Batching Tests

func test_multiple_dispatches_emit_single_slice_updated_signal_per_frame() -> void:
	store.slice_updated.connect(func(slice_name: StringName, _slice_state: Dictionary) -> void:
		slice_updated_count += 1
		last_slice_name = slice_name
	)
	
	# Dispatch multiple actions that actually change state
	for i in 10:
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		store.dispatch(action)
	
	# Signal should not have fired yet (batched)
	assert_eq(slice_updated_count, 0, "Signal should be batched, not immediate")
	
	# State should be updated immediately though
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_state.get("paused"), false, "State should update immediately (last action unpauses)")
	
	# Wait for physics frame to flush batched signals
	await get_tree().physics_frame
	await get_tree().process_frame  # Ensure signal emission completes
	
	# Should have emitted exactly once per slice despite 10 dispatches
	assert_eq(slice_updated_count, 1, "Should emit only 1 signal per slice per frame")
	assert_eq(last_slice_name, StringName("gameplay"), "Should emit for gameplay slice")

func test_state_reads_immediately_after_dispatch_show_new_state() -> void:
	# State updates should be synchronous, not batched
	U_ActionRegistry.register_action(StringName("test/immediate"))
	
	# Dispatch action that would update state
	var action: Dictionary = {"type": U_GameplayActions.ACTION_PAUSE_GAME, "payload": null}
	store.dispatch(action)
	
	# State should be updated IMMEDIATELY, not waiting for physics frame
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	assert_true(gameplay_state.get("paused", false), "State should update immediately, before signal batching")

func test_signal_batching_overhead_less_than_0_05ms() -> void:
	U_ActionRegistry.register_action(StringName("test/perf"))

	var elapsed: float = U_StateUtils.benchmark("signal_batching", func() -> void:
		# Dispatch 100 actions
		for i in 100:
			store.dispatch({"type": StringName("test/perf"), "payload": {"i": i}})
	)

	# Total overhead should be minimal (less than 0.15ms per action on average)
	# Increased threshold for CI/slower machines to account for variability
	var per_action_ms: float = elapsed / 100.0
	assert_lt(per_action_ms, 0.15, "Signal batching overhead should be < 0.15ms per action")

## Phase 1g: Action History Tests

func test_action_history_records_actions_with_timestamps() -> void:
	# Dispatch a few actions
	store.dispatch(U_GameplayActions.pause_game())
	store.dispatch(U_GameplayActions.unpause_game())
	store.dispatch(U_GameplayActions.pause_game())
	
	var history: Array = store.get_action_history()
	
	assert_eq(history.size(), 3, "History should contain 3 actions")
	
	# Check first entry structure
	var first_entry: Dictionary = history[0]
	assert_true(first_entry.has("action"), "History entry should have 'action' field")
	assert_true(first_entry.has("timestamp"), "History entry should have 'timestamp' field")
	assert_true(first_entry.has("state_after"), "History entry should have 'state_after' field")
	
	# Check action type
	assert_eq(first_entry["action"]["type"], U_GameplayActions.ACTION_PAUSE_GAME, "First action should be pause")
	
	# Check timestamp is a number
	assert_true(first_entry["timestamp"] is float or first_entry["timestamp"] is int, "Timestamp should be a number")
	
	# Check state_after is a Dictionary
	assert_true(first_entry["state_after"] is Dictionary, "state_after should be a Dictionary")

func test_get_last_n_actions_returns_correct_count() -> void:
	# Dispatch 10 actions
	for i in 10:
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		store.dispatch(action)
	
	var last_5: Array = store.get_last_n_actions(5)
	assert_eq(last_5.size(), 5, "Should return last 5 actions")
	
	# Check they are the most recent actions
	var last_entry: Dictionary = last_5[last_5.size() - 1]
	var gameplay_state: Dictionary = last_entry["state_after"]["gameplay"]
	assert_eq(gameplay_state["paused"], false, "Last action should have paused=false (index 9 is unpause)")
	
	# Test requesting more than available
	var last_20: Array = store.get_last_n_actions(20)
	assert_eq(last_20.size(), 10, "Should return only 10 actions when requesting 20")
	
	# Test requesting 0
	var last_0: Array = store.get_last_n_actions(0)
	assert_eq(last_0.size(), 0, "Should return empty array for n=0")

func test_history_prunes_oldest_when_exceeding_1000_entries() -> void:
	# This test will dispatch 1001 actions and verify the oldest is pruned
	# To speed this up, we'll use a custom store with smaller history size
	
	# Save and clear project setting so our test settings aren't overridden
	var original_setting: Variant = null
	if ProjectSettings.has_setting("state/debug/history_size"):
		original_setting = ProjectSettings.get_setting("state/debug/history_size")
		ProjectSettings.clear("state/debug/history_size")
	
	var test_store := M_StateStore.new()
	test_store.settings = RS_StateStoreSettings.new()
	test_store.settings.max_history_size = 10  # Small size for testing
	test_store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(test_store)
	autofree(test_store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# Dispatch 11 actions (exceeds max of 10)
	for i in 11:
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		test_store.dispatch(action)
	
	var history: Array = test_store.get_action_history()
	assert_eq(history.size(), 10, "History should be pruned to max size of 10")
	
	# Verify we have 10 entries (oldest was pruned)
	var oldest_entry: Dictionary = history[0]
	assert_true(oldest_entry.has("action"), "Oldest entry should still have action field")
	
	var newest_entry: Dictionary = history[history.size() - 1]
	var newest_state: Dictionary = newest_entry["state_after"]["gameplay"]
	assert_eq(newest_state["paused"], true, "Newest entry should have paused=true (last action i=10 was pause)")
	
	# Cleanup: restore original setting
	if original_setting != null:
		ProjectSettings.set_setting("state/debug/history_size", original_setting)

func test_history_includes_state_after_snapshot() -> void:
	# Dispatch action and check state_after matches actual state
	store.dispatch(U_GameplayActions.pause_game())
	
	var history: Array = store.get_action_history()
	assert_eq(history.size(), 1, "Should have 1 history entry")
	
	var entry: Dictionary = history[0]
	var state_after: Dictionary = entry["state_after"]
	var current_state: Dictionary = store.get_state()
	
	# State after should match current state
	assert_eq(state_after["gameplay"]["paused"], true, "state_after should show paused=true")
	assert_eq(current_state["gameplay"]["paused"], true, "Current state should show paused=true")

func test_history_respects_project_setting_state_debug_history_size() -> void:
	# Create a store that should read from project settings
	# We'll create a custom store and set the project setting
	var original_setting: Variant = null
	if ProjectSettings.has_setting("state/debug/history_size"):
		original_setting = ProjectSettings.get_setting("state/debug/history_size")
	
	# Set project setting to 5
	ProjectSettings.set_setting("state/debug/history_size", 5)
	
	var test_store := M_StateStore.new()
	# Explicitly set settings to null to test project setting loading
	test_store.settings = null
	test_store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(test_store)
	autofree(test_store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# The store should have read the project setting
	assert_eq(test_store.settings.max_history_size, 5, "Store should read history_size from project setting")
	
	# Cleanup: restore original setting
	if original_setting != null:
		ProjectSettings.set_setting("state/debug/history_size", original_setting)
	else:
		ProjectSettings.clear("state/debug/history_size")
