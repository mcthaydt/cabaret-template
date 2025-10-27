extends GutTest

## Performance profiling tests for M_StateStore
##
## Validates performance requirements:
## - Dispatch overhead < 0.1ms per action
## - Signal batching overhead < 0.05ms per frame
## - History tracking scales to 10,000 entries

var store: M_StateStore

func before_each() -> void:
	StateStoreEventBus.reset()
	store = M_StateStore.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame

func after_each() -> void:
	if store and is_instance_valid(store):
		store.queue_free()
	store = null

## T410: Profile M_StateStore dispatch overhead (1000 rapid dispatches)
func test_dispatch_1000_actions_overhead() -> void:
	# Profile 1000 rapid dispatches
	var elapsed_ms: float = U_StateUtils.benchmark("1000 Rapid Dispatches", func() -> void:
		for i in range(1000):
			var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
			store.dispatch(action)
	)
	
	# Calculate average per dispatch
	var avg_per_dispatch: float = elapsed_ms / 1000.0
	
	# Log results
	print("\n=== DISPATCH PERFORMANCE ===")
	print("Total time (1000 dispatches): %.3f ms" % elapsed_ms)
	print("Average per dispatch: %.6f ms" % avg_per_dispatch)
	print("Target: < 0.1 ms per dispatch")
	
	# Verify performance meets requirements
	assert_lt(avg_per_dispatch, 0.1, "Dispatch overhead should be < 0.1ms per action")

## T411: Profile individual components (dispatch, reducer, signal batching)
func test_profile_dispatch_components() -> void:
	var num_iterations: int = 100
	
	# 1. Measure raw dispatch time (no reducer logic)
	var dispatch_times: Array[float] = []
	for i in range(num_iterations):
		var start: int = Time.get_ticks_usec()
		store.dispatch(U_GameplayActions.pause_game())
		var end: int = Time.get_ticks_usec()
		dispatch_times.append((end - start) / 1000.0)
	
	var avg_dispatch_time: float = _calculate_average(dispatch_times)
	
	# 2. Measure reducer execution time
	var reducer_times: Array[float] = []
	for i in range(num_iterations):
		var current_state: Dictionary = store.get_slice(StringName("gameplay"))
		var start: int = Time.get_ticks_usec()
		var _new_state: Dictionary = GameplayReducer.reduce(current_state, U_GameplayActions.pause_game())
		var end: int = Time.get_ticks_usec()
		reducer_times.append((end - start) / 1000.0)
	
	var avg_reducer_time: float = _calculate_average(reducer_times)
	
	# 3. Measure signal batching overhead
	# Dispatch multiple actions, then measure flush time
	for i in range(10):
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		store.dispatch(action)
	
	var flush_time: float = U_StateUtils.benchmark("Signal Batch Flush", func() -> void:
		store._physics_process(0.016)  # Simulate one frame
	)
	
	# Log results
	print("\n=== COMPONENT PERFORMANCE BREAKDOWN ===")
	print("Average dispatch time: %.6f ms" % avg_dispatch_time)
	print("Average reducer time: %.6f ms" % avg_reducer_time)
	print("Signal batch flush time: %.6f ms" % flush_time)
	print("Target flush time: < 0.05 ms")
	
	# Verify signal batching is efficient
	assert_lt(flush_time, 0.05, "Signal batching should be < 0.05ms per frame")

## T412: Test .duplicate(true) overhead
func test_duplicate_overhead() -> void:
	# Create a moderately complex state
	var test_state: Dictionary = {
		"paused": false,
		"health": 100,
		"score": 1234,
		"level": 5,
		"position": Vector3(10.0, 20.0, 30.0),
		"velocity": Vector3(1.0, 2.0, 3.0),
		"nested": {
			"data": [1, 2, 3, 4, 5],
			"more": {"x": 1, "y": 2, "z": 3}
		}
	}
	
	var num_iterations: int = 1000
	
	# Measure shallow duplicate
	var shallow_time: float = U_StateUtils.benchmark("1000 Shallow Duplicates", func() -> void:
		for i in range(num_iterations):
			var _copy: Dictionary = test_state.duplicate(false)
	)
	
	# Measure deep duplicate
	var deep_time: float = U_StateUtils.benchmark("1000 Deep Duplicates", func() -> void:
		for i in range(num_iterations):
			var _copy: Dictionary = test_state.duplicate(true)
	)
	
	var shallow_avg: float = shallow_time / num_iterations
	var deep_avg: float = deep_time / num_iterations
	var overhead: float = deep_avg - shallow_avg
	
	# Log results
	print("\n=== DUPLICATE OVERHEAD ===")
	print("Shallow duplicate avg: %.6f ms" % shallow_avg)
	print("Deep duplicate avg: %.6f ms" % deep_avg)
	print("Overhead per deep duplicate: %.6f ms" % overhead)
	print("Deep duplicate used in every dispatch")
	
	# If overhead exceeds 0.1ms, consider optimization
	if deep_avg > 0.1:
		print("⚠ WARNING: Deep duplicate overhead > 0.1ms, consider optimization")
	
	# Assert that deep duplicate is reasonable (< 0.01ms for typical state)
	assert_lt(deep_avg, 0.01, "Deep duplicate should be < 0.01ms for typical state")

## T413: Profile SignalBatcher.flush() overhead
func test_signal_batcher_flush_overhead() -> void:
	# Dispatch many actions to create dirty slices
	for i in range(100):
		var action1: Dictionary = U_GameplayActions.pause_game()
		var action2: Dictionary = U_GameplayActions.unpause_game()
		store.dispatch(action1)
		store.dispatch(action2)
	
	# Measure flush time
	var flush_time: float = U_StateUtils.benchmark("SignalBatcher Flush (100 actions)", func() -> void:
		store._physics_process(0.016)
	)
	
	# Log results
	print("\n=== SIGNAL BATCHER PERFORMANCE ===")
	print("Flush time (100 actions): %.6f ms" % flush_time)
	print("Target: < 0.05 ms per frame")
	
	# Verify performance
	assert_lt(flush_time, 0.05, "SignalBatcher.flush() should be < 0.05ms per frame")

## T415: Test with 10,000 action history entries
func test_large_action_history_performance() -> void:
	# Configure large history size
	ProjectSettings.set_setting("state/debug/history_size", 10000)
	ProjectSettings.set_setting("state/debug/enable_history", true)
	
	# Create new store with large history
	var large_store: M_StateStore = M_StateStore.new()
	autofree(large_store)
	add_child(large_store)
	await get_tree().process_frame
	
	# Dispatch 10,000 actions
	var elapsed_ms: float = U_StateUtils.benchmark("10000 Actions with History", func() -> void:
		for i in range(10000):
			var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
			large_store.dispatch(action)
	)
	
	var avg_per_dispatch: float = elapsed_ms / 10000.0
	
	# Test history retrieval performance
	var retrieval_time: float = U_StateUtils.benchmark("Retrieve 10000 History Entries", func() -> void:
		var _history: Array = large_store.get_action_history()
	)
	
	# Test last N retrieval
	var last_n_time: float = U_StateUtils.benchmark("Retrieve Last 100 Entries", func() -> void:
		var _last_100: Array = large_store.get_last_n_actions(100)
	)
	
	# Log results
	print("\n=== LARGE HISTORY PERFORMANCE ===")
	print("Total time (10000 dispatches): %.3f ms" % elapsed_ms)
	print("Average per dispatch: %.6f ms" % avg_per_dispatch)
	print("History retrieval time: %.6f ms" % retrieval_time)
	print("Last 100 retrieval time: %.6f ms" % last_n_time)
	
	# Verify history doesn't cause significant overhead
	assert_lt(avg_per_dispatch, 0.1, "History tracking should not exceed 0.1ms overhead")
	# Note: Full history retrieval of 10k entries takes ~15ms due to .duplicate(true)
	# This is acceptable since retrieving ALL entries is rare; normal usage gets last N
	assert_lt(retrieval_time, 20.0, "Full history retrieval should be < 20ms")
	assert_lt(last_n_time, 1.0, "Last N retrieval should be < 1ms")
	
	# Verify circular buffer worked correctly
	var history: Array = large_store.get_action_history()
	assert_eq(history.size(), 10000, "History should contain exactly 10000 entries")
	
	# Reset project settings
	ProjectSettings.set_setting("state/debug/history_size", 1000)

## Helper: Calculate average from array of floats
func _calculate_average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for value in values:
		sum += value
	
	return sum / values.size()
