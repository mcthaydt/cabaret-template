extends BaseTest

const SessionReducer := preload("res://scripts/state/reducers/session_reducer.gd")

func test_session_reducer_returns_initial_state_on_init() -> void:
	var result: Dictionary = SessionReducer.reduce({}, {"type": StringName("@@INIT")})
	assert_eq(int(result["slot"]), 0)
	assert_eq(int(result["last_saved_tick"]), 0)
	assert_eq(result["flags"], {})

func test_session_reducer_sets_slot_and_timestamp() -> void:
	var state: Dictionary = SessionReducer.get_initial_state()
	var action: Dictionary = {
		"type": StringName("session/set_slot"),
		"payload": 2,
	}
	var next_state: Dictionary = SessionReducer.reduce(state, action)
	assert_eq(int(next_state["slot"]), 2)
	assert_eq(int(state["slot"]), 0)

	var timestamp_action: Dictionary = {
		"type": StringName("session/set_last_saved_tick"),
		"payload": 100,
	}
	var time_state: Dictionary = SessionReducer.reduce(next_state, timestamp_action)
	assert_eq(int(time_state["last_saved_tick"]), 100)

func test_session_reducer_sets_flag_without_mutating_original() -> void:
	var state: Dictionary = SessionReducer.get_initial_state()
	var payload: Dictionary = {
		"key": StringName("tutorial_complete"),
		"value": true,
	}
	var action: Dictionary = {
		"type": StringName("session/set_flag"),
		"payload": payload,
	}
	var next_state: Dictionary = SessionReducer.reduce(state, action)
	assert_true(next_state["flags"][StringName("tutorial_complete")])
	assert_false(state["flags"].has(StringName("tutorial_complete")))
