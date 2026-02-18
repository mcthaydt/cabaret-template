extends RefCounted
class_name U_TimeReducer

const U_TIME_ACTIONS := preload("res://scripts/state/actions/u_time_actions.gd")

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var action_type: Variant = action.get("type")

	match action_type:
		U_TIME_ACTIONS.ACTION_UPDATE_PAUSE_STATE:
			var payload: Dictionary = action.get("payload", {})
			return _with_values(state, {
				"is_paused": payload.get("is_paused", false),
				"active_channels": payload.get("active_channels", []).duplicate(true),
			})

		U_TIME_ACTIONS.ACTION_UPDATE_TIMESCALE:
			var scale: float = clampf(float(action.get("payload", 1.0)), 0.01, 10.0)
			return _with_values(state, {"timescale": scale})

		U_TIME_ACTIONS.ACTION_UPDATE_WORLD_TIME:
			var payload: Dictionary = action.get("payload", {})
			var hour: int = int(payload.get("world_hour", 8))
			return _with_values(state, {
				"world_hour": hour,
				"world_minute": int(payload.get("world_minute", 0)),
				"world_total_minutes": float(payload.get("world_total_minutes", 480.0)),
				"world_day_count": int(payload.get("world_day_count", 1)),
				"is_daytime": hour >= 6 and hour < 18,
			})

		U_TIME_ACTIONS.ACTION_SET_WORLD_TIME:
			var payload: Dictionary = action.get("payload", {})
			var hour: int = clampi(int(payload.get("hour", 8)), 0, 23)
			var minute: int = clampi(int(payload.get("minute", 0)), 0, 59)
			var day_count: int = int(state.get("world_day_count", 1))
			var total: float = float(day_count - 1) * 1440.0 + float(hour * 60 + minute)
			return _with_values(state, {
				"world_hour": hour,
				"world_minute": minute,
				"world_total_minutes": total,
				"is_daytime": hour >= 6 and hour < 18,
			})

		U_TIME_ACTIONS.ACTION_SET_WORLD_TIME_SPEED:
			var speed: float = maxf(float(action.get("payload", 1.0)), 0.0)
			return _with_values(state, {"world_time_speed": speed})

		_:
			return null

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = updates[key]
	return next
