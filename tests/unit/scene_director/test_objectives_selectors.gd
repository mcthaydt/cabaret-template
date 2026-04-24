extends GutTest

const OBJECTIVES_SELECTORS := preload("res://scripts/core/state/selectors/u_objectives_selectors.gd")

func test_get_objective_status_returns_status() -> void:
	var state := _make_state(
		{StringName("obj_a"): "active"},
		StringName("set_main"),
		[]
	)

	var status: String = OBJECTIVES_SELECTORS.get_objective_status(state, StringName("obj_a"))
	assert_eq(status, "active", "Selector should return stored status")

func test_get_active_objectives_returns_active_only() -> void:
	var state := _make_state(
		{
			StringName("obj_a"): "active",
			StringName("obj_b"): "completed",
			StringName("obj_c"): "failed",
			StringName("obj_d"): "active",
		},
		StringName("set_main"),
		[]
	)

	var active: Array[StringName] = OBJECTIVES_SELECTORS.get_active_objectives(state)
	assert_eq(active.size(), 2, "Only active objective IDs should be returned")
	assert_true(active.has(StringName("obj_a")), "Active objectives should include obj_a")
	assert_true(active.has(StringName("obj_d")), "Active objectives should include obj_d")

func test_is_completed_true_only_for_completed_status() -> void:
	var state := _make_state(
		{
			StringName("obj_a"): "completed",
			StringName("obj_b"): "active",
		},
		StringName("set_main"),
		[]
	)

	assert_true(
		OBJECTIVES_SELECTORS.is_completed(state, StringName("obj_a")),
		"Completed objective should return true"
	)
	assert_false(
		OBJECTIVES_SELECTORS.is_completed(state, StringName("obj_b")),
		"Non-completed objective should return false"
	)

func test_get_event_log_returns_log_array() -> void:
	var log_entries: Array[Dictionary] = [
		{
			"objective_id": StringName("obj_a"),
			"event_type": "activated",
		},
		{
			"objective_id": StringName("obj_a"),
			"event_type": "completed",
		}
	]
	var state := _make_state({}, StringName("set_main"), log_entries)

	var log: Array[Dictionary] = OBJECTIVES_SELECTORS.get_event_log(state)
	assert_eq(log, log_entries, "Selector should return event log entries")

func test_get_active_set_id_returns_set_id() -> void:
	var state := _make_state({}, StringName("set_main"), [])
	var set_id: StringName = OBJECTIVES_SELECTORS.get_active_set_id(state)
	assert_eq(set_id, StringName("set_main"), "Selector should return active set id")

func test_selectors_return_safe_defaults_on_missing_state() -> void:
	var missing_state := {}

	assert_eq(
		OBJECTIVES_SELECTORS.get_objective_status(missing_state, StringName("missing")),
		"inactive",
		"Missing objective should default to inactive"
	)
	assert_eq(
		OBJECTIVES_SELECTORS.get_active_objectives(missing_state),
		[],
		"Missing state should return empty active objective list"
	)
	assert_false(
		OBJECTIVES_SELECTORS.is_completed(missing_state, StringName("missing")),
		"Missing objective should not be completed"
	)
	assert_eq(
		OBJECTIVES_SELECTORS.get_event_log(missing_state),
		[],
		"Missing state should return empty event log"
	)
	assert_eq(
		OBJECTIVES_SELECTORS.get_active_set_id(missing_state),
		StringName(""),
		"Missing state should return empty set id"
	)
	assert_eq(
		OBJECTIVES_SELECTORS.get_active_set_ids(missing_state),
		[],
		"Missing state should return empty active_set_ids"
	)
	assert_eq(
		OBJECTIVES_SELECTORS.get_statuses_snapshot(missing_state),
		{},
		"Missing state should return empty statuses snapshot"
	)
	assert_eq(
		OBJECTIVES_SELECTORS.get_completed_objectives(missing_state),
		[],
		"Missing state should return empty completed objectives"
	)

func test_get_active_set_ids_returns_all_active_sets() -> void:
	var state := _make_state_with_set_ids(
		{},
		[StringName("set_a"), StringName("set_b")]
	)
	var active_set_ids: Array = OBJECTIVES_SELECTORS.get_active_set_ids(state)
	assert_eq(active_set_ids.size(), 2)
	assert_true(active_set_ids.has(StringName("set_a")))
	assert_true(active_set_ids.has(StringName("set_b")))

func test_get_statuses_snapshot_returns_copy() -> void:
	var state := _make_state(
		{StringName("obj_a"): "active"},
		StringName("set_main"),
		[]
	)
	var snapshot: Dictionary = OBJECTIVES_SELECTORS.get_statuses_snapshot(state)
	assert_eq(snapshot.get(StringName("obj_a")), "active")
	# Mutating snapshot should not affect state
	snapshot[StringName("obj_z")] = "failed"
	var snapshot2: Dictionary = OBJECTIVES_SELECTORS.get_statuses_snapshot(state)
	assert_false(snapshot2.has(StringName("obj_z")), "Snapshot should be a deep copy")

func test_get_completed_objectives_returns_completed_only() -> void:
	var state := _make_state(
		{
			StringName("obj_a"): "completed",
			StringName("obj_b"): "active",
			StringName("obj_c"): "completed",
		},
		StringName("set_main"),
		[]
	)
	var completed: Array[StringName] = OBJECTIVES_SELECTORS.get_completed_objectives(state)
	assert_eq(completed.size(), 2)
	assert_true(completed.has(StringName("obj_a")))
	assert_true(completed.has(StringName("obj_c")))

func _make_state(statuses: Dictionary, active_set_id: StringName, event_log: Array[Dictionary]) -> Dictionary:
	return {
		"objectives": {
			"statuses": statuses.duplicate(true),
			"active_set_id": active_set_id,
			"active_set_ids": [active_set_id] if active_set_id != StringName("") else [],
			"event_log": event_log.duplicate(true),
		}
	}

func _make_state_with_set_ids(statuses: Dictionary, active_set_ids: Array[StringName]) -> Dictionary:
	return {
		"objectives": {
			"statuses": statuses.duplicate(true),
			"active_set_id": active_set_ids[0] if active_set_ids.size() > 0 else StringName(""),
			"active_set_ids": active_set_ids.duplicate(true),
			"event_log": [],
		}
	}
