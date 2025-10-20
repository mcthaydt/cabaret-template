extends BaseTest

const STATE_MANAGER := preload("res://scripts/managers/m_state_manager.gd")

class ScoreReducer:
	static func get_slice_name() -> StringName:
		return StringName("game")

	static func get_initial_state() -> Dictionary:
		return {"score": 0}

	static func get_persistable() -> bool:
		return false

	static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
		var updated := state.duplicate(true)
		if action.get("type", StringName("")) == StringName("game/add_score"):
			updated["score"] += int(action.get("payload", 0))
		return updated

func _create_store() -> M_StateManager:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	return store

func test_history_records_entries_and_returns_deep_copy() -> void:
	var store := _create_store()
	await get_tree().process_frame

	store.register_reducer(ScoreReducer)
	store.enable_time_travel(true, 10)

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 5,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 3,
	})

	var history: Array = store.get_history()
	assert_eq(history.size(), 2)
	assert_eq(history[0]["action"]["type"], StringName("game/add_score"))
	assert_eq(int(history[0]["state"]["game"]["score"]), 5)
	assert_eq(int(history[1]["state"]["game"]["score"]), 8)

	history[0]["action"]["payload"] = 999
	history[0]["state"]["game"]["score"] = 123

	var second_copy: Array = store.get_history()
	assert_eq(int(second_copy[0]["action"]["payload"]), 5)
	assert_eq(int(second_copy[0]["state"]["game"]["score"]), 5)

func test_step_backward_and_forward_restores_state() -> void:
	var store := _create_store()
	await get_tree().process_frame

	store.register_reducer(ScoreReducer)
	store.enable_time_travel(true, 20)

	var states: Array = []
	var err := store.state_changed.connect(func(new_state: Dictionary) -> void:
		states.append(new_state.duplicate(true))
	)
	assert_eq(err, OK)

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 2,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 3,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 4,
	})

	assert_eq(int(store.get_state()["game"]["score"]), 9)

	store.step_backward()
	assert_eq(int(store.get_state()["game"]["score"]), 5)

	store.step_backward()
	assert_eq(int(store.get_state()["game"]["score"]), 2)

	store.step_backward()  # Should clamp at earliest entry.
	assert_eq(int(store.get_state()["game"]["score"]), 2)

	store.step_forward()
	assert_eq(int(store.get_state()["game"]["score"]), 5)

	store.step_forward()
	assert_eq(int(store.get_state()["game"]["score"]), 9)

	store.step_forward()  # Should clamp at latest entry.
	assert_eq(int(store.get_state()["game"]["score"]), 9)

	assert_true(states.size() >= 6)

func test_jump_to_action_and_max_history_size() -> void:
	var store := _create_store()
	await get_tree().process_frame

	store.register_reducer(ScoreReducer)
	store.enable_time_travel(true, 3)

	var payloads: Array = [1, 2, 3, 4, 5]
	for value in payloads:
		store.dispatch({
			"type": StringName("game/add_score"),
			"payload": value,
		})

	var history: Array = store.get_history()
	assert_eq(history.size(), 3)

	var expected_scores: Array = [6, 10, 15]
	for index in range(history.size()):
		assert_eq(int(history[index]["state"]["game"]["score"]), expected_scores[index])

	store.jump_to_action(1)
	assert_eq(int(store.get_state()["game"]["score"]), 10)

	store.jump_to_action(5)  # Out of range, should ignore.
	assert_eq(int(store.get_state()["game"]["score"]), 10)

	store.jump_to_action(-1)  # Negative index ignored.
	assert_eq(int(store.get_state()["game"]["score"]), 10)

func test_export_and_import_history_rebuilds_state() -> void:
	var store := _create_store()
	await get_tree().process_frame

	store.register_reducer(ScoreReducer)
	store.enable_time_travel(true, 10)

	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 4,
	})
	store.dispatch({
		"type": StringName("game/add_score"),
		"payload": 6,
	})

	var path := "user://time_travel_history.json"
	var export_err: int = store.export_history(path)
	assert_eq(export_err, OK)

	store.queue_free()
	await get_tree().process_frame

	var imported_store := _create_store()
	await get_tree().process_frame

	imported_store.register_reducer(ScoreReducer)
	imported_store.enable_time_travel(true, 10)

	var import_err: int = imported_store.import_history(path)
	assert_eq(import_err, OK)
	assert_eq(int(imported_store.get_state()["game"]["score"]), 10)
	assert_eq(imported_store.get_history().size(), 2)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
