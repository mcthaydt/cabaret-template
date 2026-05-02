extends GutTest

const OBJECTIVES_ACTIONS := preload("res://scripts/core/state/actions/u_objectives_actions.gd")
const OBJECTIVES_REDUCER := preload("res://scripts/core/state/reducers/u_objectives_reducer.gd")

func test_activate_sets_status_to_active() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.activate(StringName("obj_a"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("statuses", {}).get(StringName("obj_a")), "active")

func test_complete_sets_status_to_completed() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.complete(StringName("obj_a"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("statuses", {}).get(StringName("obj_a")), "completed")

func test_fail_sets_status_to_failed() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.fail(StringName("obj_a"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("statuses", {}).get(StringName("obj_a")), "failed")

func test_set_active_set_updates_active_set_id_and_ids() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.set_active_set(StringName("set_main"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("active_set_id"), StringName("set_main"))
	var active_set_ids: Array = reduced.get("active_set_ids", [])
	assert_true(active_set_ids.has(StringName("set_main")),
		"set_active_set should also add to active_set_ids")

func test_log_event_appends_to_event_log() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.log_event({
		"objective_id": StringName("obj_a"),
		"event_type": "activated",
	})
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)
	var event_log: Array = reduced.get("event_log", [])

	assert_eq(event_log.size(), 1, "Log event should append one entry")
	assert_eq(event_log[0].get("event_type"), "activated", "Appended event type should match payload")

func test_reset_all_clears_statuses_and_active_set_ids() -> void:
	var state := _base_state()
	var activated: Dictionary = OBJECTIVES_REDUCER.reduce(
		state,
		OBJECTIVES_ACTIONS.activate(StringName("obj_a"))
	)
	var reset_state: Dictionary = OBJECTIVES_REDUCER.reduce(activated, OBJECTIVES_ACTIONS.reset_all())

	assert_eq(reset_state.get("statuses"), {}, "reset_all should clear objective statuses")
	assert_eq(reset_state.get("active_set_ids"), [], "reset_all should clear active_set_ids")

func test_reset_for_new_run_clears_statuses_and_log_and_sets_set_id() -> void:
	var state := {
		"statuses": {
			StringName("bar_complete"): "completed",
			StringName("final_complete"): "active",
		},
		"active_set_id": StringName("old_set"),
		"active_set_ids": [StringName("old_set")],
		"event_log": [
			{"event_type": "completed", "objective_id": StringName("bar_complete")},
		],
	}

	var action := OBJECTIVES_ACTIONS.reset_for_new_run(StringName("default_progression"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("statuses"), {}, "reset_for_new_run should clear objective statuses")
	assert_eq(reduced.get("event_log"), [], "reset_for_new_run should clear objective event_log")
	assert_eq(
		reduced.get("active_set_id"),
		StringName("default_progression"),
		"reset_for_new_run should set active_set_id from payload"
	)
	assert_eq(reduced.get("active_set_ids"), [StringName("default_progression")],
		"reset_for_new_run should set active_set_ids to [set_id]")

func test_bulk_activate_marks_multiple_objectives_active() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.bulk_activate(
		[
			StringName("obj_a"),
			StringName("obj_b"),
			StringName("obj_c"),
		]
	)
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)
	var statuses: Dictionary = reduced.get("statuses", {})

	assert_eq(statuses.get(StringName("obj_a")), "active")
	assert_eq(statuses.get(StringName("obj_b")), "active")
	assert_eq(statuses.get(StringName("obj_c")), "active")

func test_reducer_is_immutable() -> void:
	var state := _base_state()
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(
		state,
		OBJECTIVES_ACTIONS.activate(StringName("obj_a"))
	)

	assert_ne(state, reduced, "Reducer should return a new state")
	assert_eq(state.get("statuses"), {}, "Original state should remain unchanged")

func test_unknown_action_returns_state_unchanged() -> void:
	var state := _base_state()
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(
		state,
		{"type": StringName("objectives/unknown")}
	)
	assert_eq(reduced, state, "Unknown action should return original state")

func test_add_active_set_appends_to_ids() -> void:
	var state := {
		"statuses": {},
		"active_set_id": StringName("set_a"),
		"active_set_ids": [StringName("set_a")],
		"event_log": [],
	}
	var action := OBJECTIVES_ACTIONS.add_active_set(StringName("set_b"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	var ids: Array = reduced.get("active_set_ids", [])
	assert_true(ids.has(StringName("set_a")), "Existing set should remain")
	assert_true(ids.has(StringName("set_b")), "New set should be added")
	assert_eq(reduced.get("active_set_id"), StringName("set_a"),
		"Primary active_set_id should remain unchanged when not empty")

func test_add_active_set_sets_primary_when_empty() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.add_active_set(StringName("set_first"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("active_set_id"), StringName("set_first"),
		"add_active_set should set primary active_set_id when empty")

func test_add_active_set_does_not_duplicate() -> void:
	var state := {
		"statuses": {},
		"active_set_id": StringName("set_a"),
		"active_set_ids": [StringName("set_a")],
		"event_log": [],
	}
	var action := OBJECTIVES_ACTIONS.add_active_set(StringName("set_a"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	var ids: Array = reduced.get("active_set_ids", [])
	assert_eq(ids.size(), 1, "Should not duplicate existing set_id")

func test_remove_active_set_removes_from_ids() -> void:
	var state := {
		"statuses": {},
		"active_set_id": StringName("set_a"),
		"active_set_ids": [StringName("set_a"), StringName("set_b")],
		"event_log": [],
	}
	var action := OBJECTIVES_ACTIONS.remove_active_set(StringName("set_b"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	var ids: Array = reduced.get("active_set_ids", [])
	assert_false(ids.has(StringName("set_b")), "Removed set should not be in active_set_ids")
	assert_true(ids.has(StringName("set_a")), "Remaining set should still be present")

func test_reset_set_statuses_removes_only_specified_ids() -> void:
	var state := {
		"statuses": {
			StringName("obj_a"): "active",
			StringName("obj_b"): "completed",
			StringName("obj_c"): "active",
		},
		"active_set_id": StringName("set_a"),
		"active_set_ids": [StringName("set_a")],
		"event_log": [],
	}
	var action := OBJECTIVES_ACTIONS.reset_set_statuses([StringName("obj_a"), StringName("obj_b")])
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	var statuses: Dictionary = reduced.get("statuses", {})
	assert_false(statuses.has(StringName("obj_a")), "Reset objective should be removed")
	assert_false(statuses.has(StringName("obj_b")), "Reset objective should be removed")
	assert_eq(statuses.get(StringName("obj_c")), "active",
		"Non-reset objective should remain")

func test_reset_all_statuses_clears_only_statuses() -> void:
	var state := {
		"statuses": {
			StringName("obj_a"): "active",
		},
		"active_set_id": StringName("set_a"),
		"active_set_ids": [StringName("set_a")],
		"event_log": [],
	}
	var action := OBJECTIVES_ACTIONS.reset_all_statuses()
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("statuses"), {}, "reset_all_statuses should clear statuses")
	assert_eq(reduced.get("active_set_id"), StringName("set_a"),
		"reset_all_statuses should preserve active_set_id")
	assert_true(reduced.get("active_set_ids", []).has(StringName("set_a")),
		"reset_all_statuses should preserve active_set_ids")

func _base_state() -> Dictionary:
	return {
		"statuses": {},
		"active_set_id": StringName(""),
		"active_set_ids": [],
		"event_log": [],
	}