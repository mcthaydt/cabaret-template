extends GutTest

const RS_TIME_INITIAL_STATE := preload("res://scripts/resources/state/rs_time_initial_state.gd")

var initial_state: Resource = null

func before_each() -> void:
	initial_state = RS_TIME_INITIAL_STATE.new()

func after_each() -> void:
	initial_state = null

func test_defaults_match_phase4_contract() -> void:
	assert_eq(initial_state.get("is_paused"), false)
	assert_eq(initial_state.get("timescale"), 1.0)
	assert_eq(initial_state.get("world_hour"), 8)
	assert_eq(initial_state.get("world_minute"), 0)
	assert_eq(initial_state.get("world_total_minutes"), 480.0)
	assert_eq(initial_state.get("world_day_count"), 1)
	assert_eq(initial_state.get("world_time_speed"), 1.0)
	assert_eq(initial_state.get("is_daytime"), true)

func test_to_dictionary_returns_independent_active_channels_copy() -> void:
	var channels: Array = [StringName("debug")]
	initial_state.set("active_channels", channels)

	var state_dict: Dictionary = initial_state.call("to_dictionary")
	channels.append(StringName("cutscene"))

	var persisted_channels: Array = state_dict.get("active_channels", [])
	assert_eq(persisted_channels.size(), 1, "to_dictionary should duplicate active_channels")
	assert_true(persisted_channels.has(StringName("debug")))
