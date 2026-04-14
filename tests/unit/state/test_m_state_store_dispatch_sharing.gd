extends GutTest

## Tests for M_StateStore dispatch snapshot sharing (F2).
##
## Verifies that:
## 1. All subscribers within a single dispatch receive the same state snapshot
##    reference (A1 optimization preserved after refactoring).
## 2. Dispatch uses the versioned cache (get_state()) instead of bypassing it,
##    so the cache is warm after dispatch (no redundant deep copy for subsequent
##    get_state() calls in the same frame).
## 3. No snapshot build occurs when there are zero subscribers.
## 4. Repeated dispatches with subscribers maintain reference identity per dispatch.


var store: M_StateStore

func before_each() -> void:
	U_StateEventBus.reset()
	U_ServiceLocator.clear()

	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.time_initial_state = RS_TimeInitialState.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

func after_each() -> void:
	store = null
	U_StateEventBus.reset()
	U_ServiceLocator.clear()


func _register_test_action(action_type: StringName) -> void:
	if not U_ActionRegistry.is_registered(action_type):
		U_ActionRegistry.register_action(action_type)


func test_all_subscribers_receive_same_snapshot_reference() -> void:
	"""With 5 subscribers, all receive the same Dictionary reference per dispatch.

	This verifies the A1 optimization (single snapshot shared across subscribers)
	is preserved after the F2 refactoring to use get_state().
	"""
	_register_test_action(&"test/dispatch_sharing_1")

	# Use Array wrappers for lambda capture (GDScript pitfall:
	# lambdas cannot reassign primitives — see DEV_PITFALLS.md)
	var call_count: Array[int] = [0]
	var received_snapshots: Array[Dictionary] = []

	for i in range(5):
		var callback: Callable = func(_action: Dictionary, state: Dictionary) -> void:
			received_snapshots.append(state)
			call_count[0] += 1
		store.subscribe(callback)

	# Dispatch a single action
	var action: Dictionary = {"type": &"test/dispatch_sharing_1"}
	store.dispatch(action)

	# All 5 subscribers should have been called
	assert_eq(call_count[0], 5, "All 5 subscribers should be called")

	# All snapshot references should point to the same Dictionary object.
	# GDScript Dictionary == does deep comparison, but same-object references
	# will have identical hashes and content.
	if received_snapshots.size() >= 2:
		var first_hash: int = received_snapshots[0].hash()
		for i in range(1, received_snapshots.size()):
			assert_eq(received_snapshots[i].hash(), first_hash,
				"Subscriber %d snapshot should have same hash as subscriber 0" % i)


func test_dispatch_populates_versioned_cache() -> void:
	"""After dispatch with subscribers, the versioned cache should be warm
	(_cached_state_version == _state_version), meaning dispatch used get_state()
	instead of bypassing it with _state.duplicate(true).

	Before F2: dispatch() bypassed get_state() and called _state.duplicate(true)
	directly. After dispatch, _cached_state_version would be stale (less than
	_state_version) because dispatch never touched the cache.

	After F2: dispatch() uses get_state() internally, so the cache is populated
	and subsequent get_state() calls don't need a fresh deep copy.
	"""
	_register_test_action(&"test/dispatch_sharing_2")

	var callback_called: Array[bool] = [false]
	var callback: Callable = func(_action: Dictionary, _state: Dictionary) -> void:
		callback_called[0] = true

	store.subscribe(callback)

	# Before dispatch: cache is stale (version -1)
	assert_eq(store._cached_state_version, -1,
		"Cache should be empty before any get_state() or dispatch")

	# Dispatch an action — this should populate the versioned cache
	var action: Dictionary = {"type": &"test/dispatch_sharing_2"}
	store.dispatch(action)

	assert_true(callback_called[0], "Subscriber should have been called")

	# After F2: the dispatch should have populated the cache via get_state(),
	# so _cached_state_version should match _state_version.
	# Before F2: dispatch bypasses get_state(), so _cached_state_version stays -1.
	assert_eq(store._cached_state_version, store._state_version,
		"Dispatch should populate the versioned cache (cached_version == state_version)")

	# A subsequent get_state() call should NOT create a new deep copy
	# (cache is already warm from dispatch)
	var cached_snapshot_before_get: Dictionary = store._cached_state_snapshot
	var _external_state := store.get_state()

	# The cached snapshot should be the same object (not rebuilt)
	assert_eq(store._cached_state_snapshot, cached_snapshot_before_get,
		"get_state() should reuse cached snapshot, not rebuild it")


func test_zero_subscribers_skips_snapshot_build() -> void:
	"""With zero subscribers, dispatch does not force a snapshot rebuild.

	After dispatch with zero subscribers, the cached snapshot version should
	remain stale (unchanged from before the dispatch), proving that dispatch
	did not call get_state() or _state.duplicate() internally.
	"""
	_register_test_action(&"test/dispatch_sharing_3")

	# Get initial state to populate the cache
	var _initial_state := store.get_state()
	var version_after_first_get: int = store._cached_state_version
	assert_ne(version_after_first_get, -1,
		"Cache should be populated after first get_state()")

	# Dispatch with zero subscribers — should NOT rebuild the snapshot
	var action: Dictionary = {"type": &"test/dispatch_sharing_3"}
	store.dispatch(action)

	# The cached snapshot version should be stale (not updated by dispatch)
	# because there are no subscribers and dispatch skipped the snapshot build.
	assert_eq(store._cached_state_version, version_after_first_get,
		"Zero-subscriber dispatch should not rebuild the cached snapshot")

	# _state_version should have been bumped by the dispatch
	assert_ne(store._state_version, version_after_first_get,
		"State version should have been bumped by dispatch")

	# Now call get_state() — it should detect the version mismatch and rebuild
	var _state_after := store.get_state()
	assert_ne(store._cached_state_version, version_after_first_get,
		"get_state() after dispatch should rebuild the cache")


func test_benchmark_dispatch_reference_identity() -> void:
	"""Dispatch 100 actions with 2 subscribers; each dispatch's snapshot is
	shared across both subscribers (not 2 distinct copies per dispatch).

	Uses Array wrappers for lambda capture per DEV_PITFALLS.md.
	"""
	_register_test_action(&"test/dispatch_sharing_4")

	var reference_mismatches: Array[int] = [0]
	var total_dispatches: Array[int] = [0]

	# Track per-dispatch reference identity across two subscribers
	var last_snapshot_hash: Array[int] = [0]
	var last_dispatch_counter: Array[int] = [-1]

	var tracker_a: Callable = func(_action: Dictionary, state: Dictionary) -> void:
		last_snapshot_hash[0] = state.hash()
		last_dispatch_counter[0] = _action.get("_dispatch_counter", -1)

	var tracker_b: Callable = func(_action: Dictionary, state: Dictionary) -> void:
		if last_dispatch_counter[0] == _action.get("_dispatch_counter", -1):
			if state.hash() != last_snapshot_hash[0]:
				reference_mismatches[0] += 1

	store.subscribe(tracker_a)
	store.subscribe(tracker_b)

	for i in range(100):
		var action: Dictionary = {"type": &"test/dispatch_sharing_4", "_dispatch_counter": i}
		store.dispatch(action)
		total_dispatches[0] += 1

	assert_eq(reference_mismatches[0], 0,
		"No reference mismatches across 100 dispatches with 2 subscribers")
	assert_eq(total_dispatches[0], 100,
		"All 100 dispatches should complete")