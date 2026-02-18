extends RefCounted
class_name U_TimeSelectors

static func get_is_paused(state: Dictionary) -> bool:
	return state.get("time", {}).get("is_paused", false)

static func get_active_channels(state: Dictionary) -> Array:
	return state.get("time", {}).get("active_channels", [])

static func get_timescale(state: Dictionary) -> float:
	return float(state.get("time", {}).get("timescale", 1.0))

static func get_world_hour(state: Dictionary) -> int:
	return int(state.get("time", {}).get("world_hour", 8))

static func get_world_minute(state: Dictionary) -> int:
	return int(state.get("time", {}).get("world_minute", 0))

static func get_world_total_minutes(state: Dictionary) -> float:
	return float(state.get("time", {}).get("world_total_minutes", 480.0))

static func get_world_day_count(state: Dictionary) -> int:
	return int(state.get("time", {}).get("world_day_count", 1))

static func get_world_time_speed(state: Dictionary) -> float:
	return float(state.get("time", {}).get("world_time_speed", 1.0))

static func is_daytime(state: Dictionary) -> bool:
	return bool(state.get("time", {}).get("is_daytime", true))
