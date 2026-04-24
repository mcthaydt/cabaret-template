extends RefCounted
class_name U_TimeActions

const ACTION_UPDATE_PAUSE_STATE := StringName("time/update_pause_state")
const ACTION_UPDATE_TIMESCALE := StringName("time/update_timescale")
const ACTION_UPDATE_WORLD_TIME := StringName("time/update_world_time")
const ACTION_SET_WORLD_TIME := StringName("time/set_world_time")
const ACTION_SET_WORLD_TIME_SPEED := StringName("time/set_world_time_speed")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_UPDATE_PAUSE_STATE)
	U_ActionRegistry.register_action(ACTION_UPDATE_TIMESCALE)
	U_ActionRegistry.register_action(ACTION_UPDATE_WORLD_TIME)
	U_ActionRegistry.register_action(ACTION_SET_WORLD_TIME)
	U_ActionRegistry.register_action(ACTION_SET_WORLD_TIME_SPEED)

static func update_pause_state(paused: bool, channels: Array) -> Dictionary:
	return {
		"type": ACTION_UPDATE_PAUSE_STATE,
		"payload": {
			"is_paused": paused,
			"active_channels": channels.duplicate(true),
		}
	}

static func update_timescale(scale: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_TIMESCALE,
		"payload": scale,
	}

static func update_world_time(hour: int, minute: int, total_minutes: float, day_count: int) -> Dictionary:
	return {
		"type": ACTION_UPDATE_WORLD_TIME,
		"payload": {
			"world_hour": hour,
			"world_minute": minute,
			"world_total_minutes": total_minutes,
			"world_day_count": day_count,
		}
	}

static func set_world_time(hour: int, minute: int) -> Dictionary:
	return {
		"type": ACTION_SET_WORLD_TIME,
		"payload": {
			"hour": hour,
			"minute": minute,
		}
	}

static func set_world_time_speed(mps: float) -> Dictionary:
	return {
		"type": ACTION_SET_WORLD_TIME_SPEED,
		"payload": mps,
	}
