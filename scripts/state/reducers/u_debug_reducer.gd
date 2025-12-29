extends RefCounted
class_name U_DebugReducer

const U_DebugActions := preload("res://scripts/state/actions/u_debug_actions.gd")

const DEFAULT_DEBUG_STATE := {
	"disable_touchscreen": false,
	"god_mode": false,
	"infinite_jump": false,
	"speed_modifier": 1.0,
	"disable_gravity": false,
	"disable_input": false,
	"time_scale": 1.0,
	"show_collision_shapes": false,
	"show_spawn_points": false,
	"show_trigger_zones": false,
	"show_entity_labels": false,
}

static func get_default_debug_state() -> Dictionary:
	return DEFAULT_DEBUG_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_DEBUG_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_DebugActions.ACTION_SET_DISABLE_TOUCHSCREEN:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"disable_touchscreen": enabled})
		U_DebugActions.ACTION_SET_GOD_MODE:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"god_mode": enabled})
		U_DebugActions.ACTION_SET_INFINITE_JUMP:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"infinite_jump": enabled})
		U_DebugActions.ACTION_SET_SPEED_MODIFIER:
			var payload: Dictionary = action.get("payload", {})
			var modifier := float(payload.get("modifier", 1.0))
			return _with_values(current, {"speed_modifier": modifier})
		U_DebugActions.ACTION_SET_DISABLE_GRAVITY:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"disable_gravity": enabled})
		U_DebugActions.ACTION_SET_DISABLE_INPUT:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"disable_input": enabled})
		U_DebugActions.ACTION_SET_TIME_SCALE:
			var payload: Dictionary = action.get("payload", {})
			var scale := float(payload.get("scale", 1.0))
			return _with_values(current, {"time_scale": scale})
		U_DebugActions.ACTION_SET_SHOW_COLLISION_SHAPES:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"show_collision_shapes": enabled})
		U_DebugActions.ACTION_SET_SHOW_SPAWN_POINTS:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"show_spawn_points": enabled})
		U_DebugActions.ACTION_SET_SHOW_TRIGGER_ZONES:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"show_trigger_zones": enabled})
		U_DebugActions.ACTION_SET_SHOW_ENTITY_LABELS:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"show_entity_labels": enabled})
		_:
			return null

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = _deep_copy(updates[key])
	return next

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
