extends GutTest

const U_TIME_SELECTORS := preload("res://scripts/state/selectors/u_time_selectors.gd")

func test_selectors_return_values_from_time_slice() -> void:
	var state := {
		"time": {
			"is_paused": true,
			"active_channels": [StringName("ui"), StringName("debug")],
			"timescale": 0.75,
			"world_hour": 12,
			"world_minute": 34,
			"world_total_minutes": 754.0,
			"world_day_count": 2,
			"world_time_speed": 2.5,
			"is_daytime": true,
		}
	}

	assert_true(U_TIME_SELECTORS.get_is_paused(state))
	assert_eq((U_TIME_SELECTORS.get_active_channels(state) as Array).size(), 2)
	assert_almost_eq(U_TIME_SELECTORS.get_timescale(state), 0.75, 0.0001)
	assert_eq(U_TIME_SELECTORS.get_world_hour(state), 12)
	assert_eq(U_TIME_SELECTORS.get_world_minute(state), 34)
	assert_almost_eq(U_TIME_SELECTORS.get_world_total_minutes(state), 754.0, 0.0001)
	assert_eq(U_TIME_SELECTORS.get_world_day_count(state), 2)
	assert_almost_eq(U_TIME_SELECTORS.get_world_time_speed(state), 2.5, 0.0001)
	assert_true(U_TIME_SELECTORS.is_daytime(state))

func test_selectors_use_defaults_when_time_slice_missing() -> void:
	var state := {}

	assert_false(U_TIME_SELECTORS.get_is_paused(state))
	assert_eq((U_TIME_SELECTORS.get_active_channels(state) as Array).size(), 0)
	assert_almost_eq(U_TIME_SELECTORS.get_timescale(state), 1.0, 0.0001)
	assert_eq(U_TIME_SELECTORS.get_world_hour(state), 8)
	assert_eq(U_TIME_SELECTORS.get_world_minute(state), 0)
	assert_almost_eq(U_TIME_SELECTORS.get_world_total_minutes(state), 480.0, 0.0001)
	assert_eq(U_TIME_SELECTORS.get_world_day_count(state), 1)
	assert_almost_eq(U_TIME_SELECTORS.get_world_time_speed(state), 1.0, 0.0001)
	assert_true(U_TIME_SELECTORS.is_daytime(state))
