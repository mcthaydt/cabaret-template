extends RefCounted
class_name U_DebugSelectors

static func get_debug_settings(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var debug_state: Variant = state.get("debug", {})
	if debug_state is Dictionary:
		return (debug_state as Dictionary).duplicate(true)
	return {}

static func is_touchscreen_disabled(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("disable_touchscreen", false))

## Skeleton selectors for Phase 0 - prevent preload errors during Phase 5 system modifications
## These will be implemented properly in Phase 1

static func is_god_mode(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("god_mode", false))

static func is_infinite_jump(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("infinite_jump", false))

static func get_speed_modifier(state: Dictionary) -> float:
	return float(get_debug_settings(state).get("speed_modifier", 1.0))

static func is_showing_collision_shapes(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("show_collision_shapes", false))

static func is_showing_spawn_points(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("show_spawn_points", false))

static func is_showing_trigger_zones(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("show_trigger_zones", false))

static func is_showing_entity_labels(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("show_entity_labels", false))

static func is_gravity_disabled(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("disable_gravity", false))

static func is_input_disabled(state: Dictionary) -> bool:
	return bool(get_debug_settings(state).get("disable_input", false))

static func get_time_scale(state: Dictionary) -> float:
	return float(get_debug_settings(state).get("time_scale", 1.0))
