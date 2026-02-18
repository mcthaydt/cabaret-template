extends GutTest

const U_TIME_ACTIONS := preload("res://scripts/state/actions/u_time_actions.gd")
const U_TIME_REDUCER := preload("res://scripts/state/reducers/u_time_reducer.gd")

func test_update_pause_state_updates_pause_fields() -> void:
	var state := _make_time_state()
	var action: Dictionary = U_TIME_ACTIONS.update_pause_state(true, [StringName("cutscene")])
	var reduced: Dictionary = U_TIME_REDUCER.reduce(state, action)

	assert_eq(reduced.get("is_paused"), true)
	assert_true((reduced.get("active_channels", []) as Array).has(StringName("cutscene")))

func test_update_timescale_clamps_range() -> void:
	var state := _make_time_state()
	var low_action: Dictionary = U_TIME_ACTIONS.update_timescale(0.0)
	var high_action: Dictionary = U_TIME_ACTIONS.update_timescale(99.0)

	var low_state: Dictionary = U_TIME_REDUCER.reduce(state, low_action)
	var high_state: Dictionary = U_TIME_REDUCER.reduce(state, high_action)

	assert_almost_eq(float(low_state.get("timescale", 0.0)), 0.01, 0.0001)
	assert_almost_eq(float(high_state.get("timescale", 0.0)), 10.0, 0.0001)

func test_update_world_time_sets_values_and_is_daytime() -> void:
	var state := _make_time_state()
	var day_action: Dictionary = U_TIME_ACTIONS.update_world_time(7, 30, 450.0, 1)
	var night_action: Dictionary = U_TIME_ACTIONS.update_world_time(22, 0, 1320.0, 1)

	var day_state: Dictionary = U_TIME_REDUCER.reduce(state, day_action)
	var night_state: Dictionary = U_TIME_REDUCER.reduce(state, night_action)

	assert_eq(int(day_state.get("world_hour", -1)), 7)
	assert_eq(int(day_state.get("world_minute", -1)), 30)
	assert_eq(day_state.get("is_daytime"), true)
	assert_eq(night_state.get("is_daytime"), false)

func test_set_world_time_clamps_and_recomputes_total() -> void:
	var state := _make_time_state()
	state["world_day_count"] = 3
	var action: Dictionary = U_TIME_ACTIONS.set_world_time(30, -10)
	var reduced: Dictionary = U_TIME_REDUCER.reduce(state, action)

	assert_eq(int(reduced.get("world_hour", -1)), 23)
	assert_eq(int(reduced.get("world_minute", -1)), 0)
	assert_almost_eq(float(reduced.get("world_total_minutes", -1.0)), 4260.0, 0.0001)

func test_set_world_time_speed_clamps_non_negative() -> void:
	var state := _make_time_state()
	var action: Dictionary = U_TIME_ACTIONS.set_world_time_speed(-5.0)
	var reduced: Dictionary = U_TIME_REDUCER.reduce(state, action)

	assert_almost_eq(float(reduced.get("world_time_speed", -1.0)), 0.0, 0.0001)

func test_unknown_action_returns_null() -> void:
	var state := _make_time_state()
	var reduced: Variant = U_TIME_REDUCER.reduce(state, {"type": StringName("time/unknown")})

	assert_null(reduced)

func _make_time_state() -> Dictionary:
	return {
		"is_paused": false,
		"active_channels": [],
		"timescale": 1.0,
		"world_hour": 8,
		"world_minute": 0,
		"world_total_minutes": 480.0,
		"world_day_count": 1,
		"world_time_speed": 1.0,
		"is_daytime": true,
	}
