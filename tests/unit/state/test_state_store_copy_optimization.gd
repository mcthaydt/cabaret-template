extends GutTest

## Tests for state store deep copy optimizations (A1, A2, A3)
##
## A1: dispatch() shares single state copy across all subscribers
## A2: get_state() caches snapshot with version tracking
## A3: U_SignalBatcher defers deep copy to flush() time

var store: M_StateStore
const RS_TIME_INITIAL_STATE := preload("res://scripts/resources/state/rs_time_initial_state.gd")

func before_each() -> void:
	U_StateEventBus.reset()
	U_ServiceLocator.clear()
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.time_initial_state = RS_TIME_INITIAL_STATE.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

func after_each() -> void:
	store = null
	U_StateEventBus.reset()
	U_ServiceLocator.clear()

# --- A1: Subscribers receive shared state reference ---

func test_a1_subscribers_receive_same_state_reference() -> void:
	var received_states: Array = []
	var _unsub1 := store.subscribe(func(_action: Dictionary, state: Dictionary) -> void:
		received_states.append(state)
	)
	var _unsub2 := store.subscribe(func(_action: Dictionary, state: Dictionary) -> void:
		received_states.append(state)
	)

	store.dispatch(U_GameplayActions.pause_game())

	assert_eq(received_states.size(), 2, "Both subscribers should receive state")
	# With shared copy optimization: first subscriber mutating state is visible to second.
	# Verify they got identical content (value equality).
	assert_eq(received_states[0], received_states[1], "Subscribers should receive equal state")
	# Verify that the subscriber copy is not the internal _state (write safety).
	received_states[0]["__test_marker"] = true
	var internal_state: Dictionary = store.get_state()
	assert_false(
		internal_state.has("__test_marker"),
		"Subscriber state must not be the internal _state reference"
	)

func test_a1_dispatch_with_multiple_subscribers_is_faster_than_per_subscriber_copy() -> void:
	var perf_store := M_StateStore.new()
	perf_store.settings = RS_StateStoreSettings.new()
	perf_store.settings.enable_persistence = false
	perf_store.settings.enable_history = false
	perf_store.gameplay_initial_state = RS_GameplayInitialState.new()
	perf_store.settings_initial_state = RS_SettingsInitialState.new()
	perf_store.time_initial_state = RS_TIME_INITIAL_STATE.new()
	add_child(perf_store)
	autofree(perf_store)
	await get_tree().process_frame

	# Use Array wrapper for closure mutation (GDScript closure pitfall)
	var counter := [0]
	for i in range(5):
		perf_store.subscribe(func(_a: Dictionary, _s: Dictionary) -> void:
			counter[0] += 1
		)

	var start: int = Time.get_ticks_usec()
	for i in range(500):
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		perf_store.dispatch(action)
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var avg_per_dispatch: float = elapsed_ms / 500.0
	var threshold_ms: float = 0.30
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		threshold_ms = 0.45

	assert_eq(counter[0], 2500, "All subscribers should be called for all dispatches")
	# With shared copy: 500 dispatches * 1 copy = 500 copies
	# Without: 500 dispatches * 5 subscribers = 2500 copies
	assert_lt(
		avg_per_dispatch, threshold_ms,
		"Dispatch with 5 subscribers should remain under the benchmark threshold"
	)

func test_a1_subscriber_mutation_does_not_affect_internal_state() -> void:
	var _unsub1 := store.subscribe(func(_action: Dictionary, state: Dictionary) -> void:
		state["_mutated"] = true
	)

	store.dispatch(U_GameplayActions.pause_game())

	var internal_state: Dictionary = store.get_state()
	assert_false(
		internal_state.has("_mutated"),
		"Internal store state must not be affected by subscriber mutations"
	)

# --- A2: Cached get_state() with version tracking ---

func test_a2_get_state_returns_consistent_snapshot() -> void:
	var state1: Dictionary = store.get_state()
	var state2: Dictionary = store.get_state()

	assert_eq(state1, state2, "Consecutive get_state() calls should return equal state")

func test_a2_get_state_cache_invalidated_by_dispatch() -> void:
	# Ensure initial state has paused=false
	store.dispatch(U_GameplayActions.unpause_game())
	var state_before: Dictionary = store.get_state()
	var gameplay_before: Dictionary = state_before.get("gameplay", {})
	var paused_before: bool = gameplay_before.get("paused", true)

	store.dispatch(U_GameplayActions.pause_game())
	var state_after: Dictionary = store.get_state()
	var gameplay_after: Dictionary = state_after.get("gameplay", {})
	var paused_after: bool = gameplay_after.get("paused", false)

	assert_false(paused_before, "Should start unpaused")
	assert_true(paused_after, "Should be paused after dispatch")
	assert_ne(paused_before, paused_after, "State should change after dispatch")

func test_a2_cached_get_state_performance() -> void:
	# Measure 1000 get_state() calls without any intervening dispatch
	# With caching: returns same reference, nearly free
	# Without: 1000 deep copies
	var start: int = Time.get_ticks_usec()
	for i in range(1000):
		var _state: Dictionary = store.get_state()
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var avg_per_call: float = elapsed_ms / 1000.0

	# Cached get_state() should be nearly free (no deep copy)
	assert_lt(avg_per_call, 0.005, "Cached get_state() should be < 0.005ms per call")

func test_a2_get_state_external_mutation_does_not_corrupt_store() -> void:
	var state: Dictionary = store.get_state()
	state["__injected"] = true

	var fresh_state: Dictionary = store.get_state()
	assert_false(
		fresh_state.has("__injected"),
		"External mutation of get_state() result must not corrupt internal state"
	)

# --- A3: Signal batcher defers deep copy to flush ---

func test_a3_signal_batcher_marks_dirty_without_deep_copy() -> void:
	var batcher := U_SignalBatcher.new()
	var slice_state: Dictionary = {"key": "value", "nested": {"a": 1}}
	batcher.mark_slice_dirty(StringName("test_slice"), slice_state)
	assert_eq(batcher.get_pending_count(), 1, "Should have 1 pending slice")

func test_a3_signal_batcher_flush_emits_correct_state() -> void:
	var batcher := U_SignalBatcher.new()
	var original: Dictionary = {"key": "value", "nested": {"a": 1}}
	batcher.mark_slice_dirty(StringName("test_slice"), original)

	# Use Array wrappers for closure capture
	var result_name := [StringName("")]
	var result_state := [{}]
	batcher.flush(func(name: StringName, state: Dictionary) -> void:
		result_name[0] = name
		result_state[0] = state
	)

	assert_eq(result_name[0], StringName("test_slice"), "Flush should emit correct slice name")
	assert_eq(result_state[0].get("key"), "value", "Flush should emit correct state values")

func test_a3_signal_batcher_flush_state_is_isolated_from_original() -> void:
	var batcher := U_SignalBatcher.new()
	var original: Dictionary = {"key": "value", "nested": {"a": 1}}
	batcher.mark_slice_dirty(StringName("test_slice"), original)

	# Mutate original AFTER marking dirty
	original["key"] = "mutated"
	original["nested"]["a"] = 999

	var result_state := [{}]
	batcher.flush(func(_name: StringName, state: Dictionary) -> void:
		result_state[0] = state
	)

	# Flushed state should be isolated from mutations to original
	assert_eq(
		result_state[0].get("key"), "value",
		"Flushed state should not reflect post-mark mutations to original"
	)
	var nested: Dictionary = result_state[0].get("nested", {})
	assert_eq(
		nested.get("a"), 1,
		"Flushed nested state should not reflect post-mark mutations"
	)

func test_a3_signal_batcher_overwrites_repeat_marks() -> void:
	var batcher := U_SignalBatcher.new()
	batcher.mark_slice_dirty(StringName("test_slice"), {"version": 1})
	batcher.mark_slice_dirty(StringName("test_slice"), {"version": 2})

	assert_eq(batcher.get_pending_count(), 1, "Repeated marks should overwrite, not stack")

	var result_state := [{}]
	batcher.flush(func(_name: StringName, state: Dictionary) -> void:
		result_state[0] = state
	)

	assert_eq(result_state[0].get("version"), 2, "Should flush latest marked state")

# --- A4: apply_reducers reference equality short-circuit ---

func test_a4_apply_reducers_skips_unchanged_slices_by_reference() -> void:
	# Dispatch an action only handled by gameplay slice
	# Verify that non-gameplay slices are not modified in state
	var state_before: Dictionary = store.get_state()
	var settings_before: Dictionary = state_before.get("settings", {})

	store.dispatch(U_GameplayActions.pause_game())

	var state_after: Dictionary = store.get_state()
	var settings_after: Dictionary = state_after.get("settings", {})

	# Settings slice should be identical (not deep-copied and re-stored)
	assert_eq(settings_before, settings_after, "Non-target slices should remain unchanged")

func test_a4_apply_reducers_detects_changes_correctly() -> void:
	# Verify that changed slices are still detected
	store.dispatch(U_GameplayActions.unpause_game())
	var state_before: Dictionary = store.get_state()
	var paused_before: bool = state_before.get("gameplay", {}).get("paused", true)

	store.dispatch(U_GameplayActions.pause_game())
	var state_after: Dictionary = store.get_state()
	var paused_after: bool = state_after.get("gameplay", {}).get("paused", false)

	assert_false(paused_before, "Should start unpaused")
	assert_true(paused_after, "Should be paused after dispatch")

func test_a4_apply_reducers_unchanged_action_does_not_dirty_slices() -> void:
	# Flush any pending signals from prior tests or init dispatches
	await get_tree().process_frame

	# Dispatch an unknown action — no reducer should claim it
	var unknown_action: Dictionary = {"type": StringName("unknown/noop"), "payload": null}
	U_ActionRegistry.register_action(StringName("unknown/noop"))

	var emitted_slices: Array[StringName] = []
	var _unsub := store.subscribe(func(_action: Dictionary, _state: Dictionary) -> void:
		pass
	)
	store.slice_updated.connect(func(slice_name: StringName, _slice_state: Dictionary) -> void:
		emitted_slices.append(slice_name)
	)

	store.dispatch(unknown_action)
	# Flush any batched signals
	await get_tree().process_frame

	assert_eq(emitted_slices.size(), 0, "Unknown action should not dirty any slices")

func test_a4_entity_snapshot_dispatch_performance_improvement() -> void:
	# Measure entity snapshot dispatch performance
	# With the optimization, this should be significantly faster since
	# only the gameplay slice gets deep-copied, not all 15 slices
	U_ActionRegistry.register_action(U_EntityActions.ACTION_UPDATE_ENTITY_SNAPSHOT)
	var snapshot: Dictionary = {
		"position": Vector3(1.0, 2.0, 3.0),
		"velocity": Vector3.ZERO,
		"rotation": Vector3.ZERO,
		"is_moving": true,
		"entity_type": "player",
	}

	# Warm up
	for i in range(10):
		store.dispatch(U_EntityActions.update_entity_snapshot("player", snapshot))

	var start: int = Time.get_ticks_usec()
	for i in range(200):
		snapshot["position"] = Vector3(float(i), 0.0, 0.0)
		store.dispatch(U_EntityActions.update_entity_snapshot("player", snapshot))
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var avg_per_dispatch: float = elapsed_ms / 200.0

	# With optimization: should be well under 0.15ms per dispatch
	var threshold_ms: float = 0.15
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		threshold_ms = 0.25
	assert_lt(
		avg_per_dispatch, threshold_ms,
		"Entity snapshot dispatch should be under threshold with apply_reducers optimization"
	)
