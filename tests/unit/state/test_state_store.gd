extends GutTest

const STATE_MANAGER := preload("res://scripts/state/m_state_manager.gd")
const U_SelectorUtils := preload("res://scripts/state/u_selector_utils.gd")
const U_StateStoreUtils := preload("res://scripts/state/u_state_store_utils.gd")

class FakeReducer:
	static func get_slice_name() -> StringName:
		return StringName("game")

	static func get_initial_state() -> Dictionary:
		return {"score": 0}

	static func get_persistable() -> bool:
		return false

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

func test_register_reducer_initializes_state() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var state: Dictionary = store.get_state()
	assert_true(state.has("game"))
	assert_eq(state["game"]["score"], 0)

	store.queue_free()
	await get_tree().process_frame

func test_dispatch_updates_state_and_emits_signals() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
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
	store.queue_free()
	await get_tree().process_frame

func test_select_supports_path_and_memoized_selector() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
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

	store.queue_free()
	await get_tree().process_frame

func test_subscribe_returns_callable_that_disconnects() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
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

	store.queue_free()
	await get_tree().process_frame

func test_state_store_utils_discovers_store_in_hierarchy_and_group() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	await get_tree().process_frame

	store.register_reducer(FakeReducer)

	var child: Node = Node.new()
	store.add_child(child)
	await get_tree().process_frame

	var found_from_child: Node = U_StateStoreUtils.get_store(child)
	assert_eq(found_from_child, store)

	var sibling: Node = Node.new()
	add_child(sibling)
	await get_tree().process_frame

	var found_from_sibling: Node = U_StateStoreUtils.get_store(sibling)
	assert_eq(found_from_sibling, store)

	child.queue_free()
	sibling.queue_free()
	store.queue_free()
	await get_tree().process_frame

func test_memoized_selector_dependency_tracking_skips_unrelated_changes() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
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

	store.queue_free()
	await get_tree().process_frame
