extends RefCounted
class_name U_TimeSelectors

## Time state selectors
##
## All methods accept full state; slice extraction is handled internally.

static func get_is_paused(state: Dictionary) -> bool:
	return _get_time_slice(state).get("is_paused", false)

static func get_active_channels(state: Dictionary) -> Array:
	var channels: Variant = _get_time_slice(state).get("active_channels", [])
	if channels is Array:
		return channels as Array
	return []

static func get_timescale(state: Dictionary) -> float:
	return float(_get_time_slice(state).get("timescale", 1.0))

static func get_world_hour(state: Dictionary) -> int:
	return int(_get_time_slice(state).get("world_hour", 8))

static func get_world_minute(state: Dictionary) -> int:
	return int(_get_time_slice(state).get("world_minute", 0))

static func get_world_total_minutes(state: Dictionary) -> float:
	return float(_get_time_slice(state).get("world_total_minutes", 480.0))

static func get_world_day_count(state: Dictionary) -> int:
	return int(_get_time_slice(state).get("world_day_count", 1))

static func get_world_time_speed(state: Dictionary) -> float:
	return float(_get_time_slice(state).get("world_time_speed", 1.0))

static func is_daytime(state: Dictionary) -> bool:
	return bool(_get_time_slice(state).get("is_daytime", true))

## Private: extract time slice from full state
static func _get_time_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	# If state has a "time" key, extract the nested slice (full state passed)
	var time: Variant = state.get("time", null)
	if time is Dictionary:
		return time as Dictionary
	# If state has "timescale" key, it's already the time slice (backward compat)
	if state.has("timescale"):
		return state
	return {}