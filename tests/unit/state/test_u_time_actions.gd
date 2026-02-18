extends GutTest

const U_TIME_ACTIONS := preload("res://scripts/state/actions/u_time_actions.gd")

func test_update_pause_state_builds_expected_payload() -> void:
	var channels: Array = [StringName("cutscene")]
	var action: Dictionary = U_TIME_ACTIONS.update_pause_state(true, channels)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_TIME_ACTIONS.ACTION_UPDATE_PAUSE_STATE)
	assert_eq(payload.get("is_paused"), true)
	assert_true((payload.get("active_channels", []) as Array).has(StringName("cutscene")))

func test_update_pause_state_duplicates_channels_array() -> void:
	var channels: Array = [StringName("debug")]
	var action: Dictionary = U_TIME_ACTIONS.update_pause_state(false, channels)
	channels.append(StringName("system"))

	var payload_channels: Array = action.get("payload", {}).get("active_channels", [])
	assert_eq(payload_channels.size(), 1)
	assert_true(payload_channels.has(StringName("debug")))

func test_update_timescale_builds_expected_action() -> void:
	var action: Dictionary = U_TIME_ACTIONS.update_timescale(0.5)

	assert_eq(action.get("type"), U_TIME_ACTIONS.ACTION_UPDATE_TIMESCALE)
	assert_almost_eq(float(action.get("payload", 0.0)), 0.5, 0.0001)

func test_update_world_time_builds_expected_payload() -> void:
	var action: Dictionary = U_TIME_ACTIONS.update_world_time(9, 15, 555.0, 2)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_TIME_ACTIONS.ACTION_UPDATE_WORLD_TIME)
	assert_eq(int(payload.get("world_hour", -1)), 9)
	assert_eq(int(payload.get("world_minute", -1)), 15)
	assert_almost_eq(float(payload.get("world_total_minutes", -1.0)), 555.0, 0.0001)
	assert_eq(int(payload.get("world_day_count", -1)), 2)

func test_set_world_time_builds_expected_payload() -> void:
	var action: Dictionary = U_TIME_ACTIONS.set_world_time(22, 45)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_TIME_ACTIONS.ACTION_SET_WORLD_TIME)
	assert_eq(int(payload.get("hour", -1)), 22)
	assert_eq(int(payload.get("minute", -1)), 45)

func test_set_world_time_speed_builds_expected_payload() -> void:
	var action: Dictionary = U_TIME_ACTIONS.set_world_time_speed(3.0)

	assert_eq(action.get("type"), U_TIME_ACTIONS.ACTION_SET_WORLD_TIME_SPEED)
	assert_almost_eq(float(action.get("payload", -1.0)), 3.0, 0.0001)
