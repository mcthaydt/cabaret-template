extends GutTest

const OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")
const OBJECTIVES_REDUCER := preload("res://scripts/state/reducers/u_objectives_reducer.gd")

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

func test_set_active_set_updates_active_set_id() -> void:
	var state := _base_state()
	var action := OBJECTIVES_ACTIONS.set_active_set(StringName("set_main"))
	var reduced: Dictionary = OBJECTIVES_REDUCER.reduce(state, action)

	assert_eq(reduced.get("active_set_id"), StringName("set_main"))

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

func test_reset_all_clears_statuses() -> void:
	var state := _base_state()
	var activated: Dictionary = OBJECTIVES_REDUCER.reduce(
		state,
		OBJECTIVES_ACTIONS.activate(StringName("obj_a"))
	)
	var reset_state: Dictionary = OBJECTIVES_REDUCER.reduce(activated, OBJECTIVES_ACTIONS.reset_all())

	assert_eq(reset_state.get("statuses"), {}, "reset_all should clear objective statuses")

func test_reset_for_new_run_clears_statuses_and_log_and_sets_set_id() -> void:
	var state := {
		"statuses": {
			StringName("bar_complete"): "completed",
			StringName("final_complete"): "active",
		},
		"active_set_id": StringName("old_set"),
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

func _base_state() -> Dictionary:
	return {
		"statuses": {},
		"active_set_id": StringName(""),
		"event_log": [],
	}
