extends BaseTest

const STATE_MANAGER := preload("res://scripts/managers/m_state_manager.gd")
const U_SelectorUtils := preload("res://scripts/state/u_selector_utils.gd")
const U_StateStoreUtils := preload("res://scripts/state/u_state_store_utils.gd")

class FakeReducer:
	static func get_slice_name() -> StringName:
		return StringName("game")

	static func get_initial_state() -> Dictionary:
		return {"score": 0}

	static func get_persistable() -> bool:
		return true

	static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
		var action_type: StringName = action.get("type", StringName(""))
		if action_type == StringName("game/add_score"):
			var updated := state.duplicate(true)
			updated["score"] += int(action.get("payload", 0))
			return updated
		if action_type == StringName("game/reset_score"):
			var updated := state.duplicate(true)
			updated["score"] = 0
			return updated
		return state

class OtherReducer:
	static func get_slice_name() -> StringName:
		return StringName("other")

	static func get_initial_state() -> Dictionary:
		return {"flag": false}

	static func get_persistable() -> bool:
		return false

	static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
		var updated := state.duplicate(true)
		if action.get("type", StringName("")) == StringName("other/toggle"):
			updated["flag"] = !bool(updated.get("flag", false))
		return updated

class PersistedReducer:
	static func get_slice_name() -> StringName:
		return StringName("session")

	static func get_initial_state() -> Dictionary:
		return {"value": 0}

	static func get_persistable() -> bool:
		return true

	static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
		var updated := state.duplicate(true)
		match action.get("type", StringName("")):
			StringName("session/set_value"):
				updated["value"] = int(action.get("payload", 0))
			StringName("session/clear"):
				updated["value"] = 0
		return updated

func test_register_reducer_initializes_state() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var state: Dictionary = store.get_state()
	assert_true(state.has("game"))
	assert_eq(state["game"]["score"], 0)

func test_dispatch_updates_state_and_emits_signals() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var actions: Array = []
	var states: Array = []
	var unsub: Callable = store.subscribe(func(new_state: Dictionary) -> void:
		states.append(new_state.duplicate(true))
	)
	var dispatch_err: Error = store.action_dispatched.connect(func(dispatched: Dictionary) -> void:
		actions.append(dispatched.duplicate(true))
	)
	assert_eq(dispatch_err, OK)

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 5,
	})

	var state: Dictionary = store.get_state()
	assert_eq(state["game"]["score"], 5)
	assert_eq(actions.size(), 1)
	assert_eq(actions[0]["type"], StringName("game/add_score"))
	assert_eq(states.size(), 1)
	assert_eq(states[0]["game"]["score"], 5)

	unsub.call()

func test_select_supports_path_and_memoized_selector() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var score: int = store.select("game.score") as int
	assert_eq(score, 0)

	var compute_calls: Array = [0]
	var MemoizedSelector: GDScript = U_SelectorUtils.MemoizedSelector
	var selector: RefCounted = MemoizedSelector.new(func(state: Dictionary) -> bool:
		compute_calls[0] += 1
		return int(state["game"]["score"]) > 0
	)

	var first_result: bool = bool(store.select(selector))
	assert_false(first_result)
	assert_eq(compute_calls[0], 1)

	var second_result: bool = bool(store.select(selector))
	assert_false(second_result)
	assert_eq(compute_calls[0], 1, "Selector should not recompute without state change")

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 1,
	})

	var third_result: bool = bool(store.select(selector))
	assert_true(third_result)
	assert_eq(compute_calls[0], 2)

func test_subscribe_returns_callable_that_disconnects() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var notifications: Array = [0]
	var unsubscribe: Callable = store.subscribe(func(_state: Dictionary) -> void:
		notifications[0] += 1
	)

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 3,
	})
	assert_eq(notifications[0], 1)

	unsubscribe.call()

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 2,
	})
	assert_eq(notifications[0], 1)

func test_state_store_utils_discovers_store_in_hierarchy_and_group() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var child: Node = Node.new()
	store.add_child(child)
	autofree(child)
	await get_tree().process_frame

	var found_from_child: Node = U_StateStoreUtils.get_store(child)
	assert_eq(found_from_child, store)

	var sibling: Node = Node.new()
	add_child(sibling)
	autofree(sibling)
	await get_tree().process_frame

	var found_from_sibling: Node = U_StateStoreUtils.get_store(sibling)
	assert_eq(found_from_sibling, store)

func test_memoized_selector_dependency_tracking_skips_unrelated_changes() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)
	store.register_reducer(OtherReducer)

	var compute_calls: Array = [0]
	var MemoizedSelector: GDScript = U_SelectorUtils.MemoizedSelector
	var selector: RefCounted = MemoizedSelector.new(func(state: Dictionary) -> int:
		compute_calls[0] += 1
		return int(state["game"]["score"])
	).with_dependencies(["game.score"])

	var initial: int = int(store.select(selector))
	assert_eq(initial, 0)
	assert_eq(compute_calls[0], 1)

	store.dispatch({
		"type": StringName("other/toggle"),
	})
	var after_other: int = int(store.select(selector))
	assert_eq(after_other, 0)
	assert_eq(compute_calls[0], 1)

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 2,
	})
	var after_game: int = int(store.select(selector))
	assert_eq(after_game, 2)
	assert_eq(compute_calls[0], 2)

	var metrics: Dictionary = selector.get_metrics()
	assert_eq(int(metrics["cache_hits"]), 1)
	assert_eq(int(metrics["cache_misses"]), 2)
	assert_eq(int(metrics["dependency_hits"]), 1)
	assert_eq(int(metrics["dependency_misses"]), 2)

	selector.reset_metrics()
	metrics = selector.get_metrics()
	assert_eq(int(metrics["cache_hits"]), 0)
	assert_eq(int(metrics["cache_misses"]), 0)
	assert_eq(int(metrics["dependency_hits"]), 0)
	assert_eq(int(metrics["dependency_misses"]), 0)

func test_save_and_load_state_round_trip() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(PersistedReducer)
	store.register_reducer(FakeReducer)

	store.dispatch({
		"type": StringName("session/set_value"),
		"payload": 12,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 4,
	})

	var path := "user://state_manager_save.json"
	var save_err: Error = store.save_state(path)
	assert_eq(save_err, OK)

	store.dispatch({
		"type": StringName("session/set_value"),
		"payload": 99,
	})
	store.dispatch({
		"type": StringName("game/reset_score"),
	})

	var load_err: Error = store.load_state(path)
	assert_eq(load_err, OK)

	var state: Dictionary = store.get_state()
	assert_eq(int(state[StringName("session")]["value"]), 12)
	assert_eq(int(state[StringName("game")]["score"]), 4)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func test_save_state_allows_whitelist_override() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(PersistedReducer)
	store.register_reducer(FakeReducer)

	store.dispatch({
		"type": StringName("session/set_value"),
		"payload": 8,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 3,
	})

	var path := "user://state_manager_whitelist.json"
	var save_err: Error = store.save_state(path, [StringName("game")])
	assert_eq(save_err, OK)

	store.dispatch({
		"type": StringName("session/set_value"),
		"payload": 42,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 7,
	})

	var load_err: Error = store.load_state(path)
	assert_eq(load_err, OK)

	var state: Dictionary = store.get_state()
	assert_eq(int(state[StringName("game")]["score"]), 3)
	assert_eq(int(state[StringName("session")]["value"]), 42)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func test_dispatch_with_no_reducers_does_not_crash() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	# No reducers registered
	var notifications: Array = []
	var unsubscribe: Callable = store.subscribe(func(state: Dictionary) -> void:
		notifications.append(state.duplicate(true))
	)

	# Should not crash or error
	store.dispatch({
		"type": StringName("test/action"),
	})

	# Assert a state_changed signal was emitted with empty state
	assert_eq(notifications.size(), 1)
	assert_true((notifications[0] as Dictionary).is_empty())

	unsubscribe.call()

func test_get_state_returns_deep_copy() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	# Set nested value in store state
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 1,
	})

	# Get a copy and mutate it (both top-level and nested)
	var snapshot: Dictionary = store.get_state()
	assert_eq(int(snapshot[StringName("game")]["score"]), 1)
	snapshot[StringName("extra_key")] = 123
	var game_slice: Dictionary = snapshot[StringName("game")]
	game_slice["score"] = 999
	snapshot[StringName("game")] = game_slice

	# Fetch state again; original store must be unchanged
	var after: Dictionary = store.get_state()
	assert_false(after.has(StringName("extra_key")))
	assert_eq(int(after[StringName("game")]["score"]), 1)

func test_ready_initializes_state_from_reducers() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	# Register reducer before the node is added to the scene
	store.register_reducer(FakeReducer)

	add_child(store)
	autofree(store)
	await get_tree().process_frame

	# _ready should have run; state should reflect reducer initial state
	var state: Dictionary = store.get_state()
	assert_true(state.has(StringName("game")))
	assert_eq(int(state[StringName("game")]["score"]), 0)
	# And the store should be discoverable via group
	assert_true(store.is_in_group("state_store"))
