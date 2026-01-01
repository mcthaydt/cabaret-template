extends RefCounted
class_name U_DebugActions

const U_ActionRegistry := preload("res://scripts/state/utils/u_action_registry.gd")

# Existing action
const ACTION_SET_DISABLE_TOUCHSCREEN := StringName("debug/set_disable_touchscreen")

# Phase 1: Debug toggle actions
const ACTION_SET_GOD_MODE := StringName("debug/set_god_mode")
const ACTION_SET_INFINITE_JUMP := StringName("debug/set_infinite_jump")
const ACTION_SET_SPEED_MODIFIER := StringName("debug/set_speed_modifier")
const ACTION_SET_DISABLE_GRAVITY := StringName("debug/set_disable_gravity")
const ACTION_SET_DISABLE_INPUT := StringName("debug/set_disable_input")
const ACTION_SET_TIME_SCALE := StringName("debug/set_time_scale")
const ACTION_SET_SHOW_COLLISION_SHAPES := StringName("debug/set_show_collision_shapes")
const ACTION_SET_SHOW_SPAWN_POINTS := StringName("debug/set_show_spawn_points")
const ACTION_SET_SHOW_TRIGGER_ZONES := StringName("debug/set_show_trigger_zones")
const ACTION_SET_SHOW_ENTITY_LABELS := StringName("debug/set_show_entity_labels")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_DISABLE_TOUCHSCREEN)
	U_ActionRegistry.register_action(ACTION_SET_GOD_MODE)
	U_ActionRegistry.register_action(ACTION_SET_INFINITE_JUMP)
	U_ActionRegistry.register_action(ACTION_SET_SPEED_MODIFIER)
	U_ActionRegistry.register_action(ACTION_SET_DISABLE_GRAVITY)
	U_ActionRegistry.register_action(ACTION_SET_DISABLE_INPUT)
	U_ActionRegistry.register_action(ACTION_SET_TIME_SCALE)
	U_ActionRegistry.register_action(ACTION_SET_SHOW_COLLISION_SHAPES)
	U_ActionRegistry.register_action(ACTION_SET_SHOW_SPAWN_POINTS)
	U_ActionRegistry.register_action(ACTION_SET_SHOW_TRIGGER_ZONES)
	U_ActionRegistry.register_action(ACTION_SET_SHOW_ENTITY_LABELS)

static func set_disable_touchscreen(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DISABLE_TOUCHSCREEN,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

static func set_god_mode(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_GOD_MODE,
		"payload": {
			"enabled": enabled
		}
	}

static func set_infinite_jump(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_INFINITE_JUMP,
		"payload": {
			"enabled": enabled
		}
	}

static func set_speed_modifier(modifier: float) -> Dictionary:
	return {
		"type": ACTION_SET_SPEED_MODIFIER,
		"payload": {
			"modifier": modifier
		}
	}

static func set_disable_gravity(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DISABLE_GRAVITY,
		"payload": {
			"enabled": enabled
		}
	}

static func set_disable_input(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DISABLE_INPUT,
		"payload": {
			"enabled": enabled
		}
	}

static func set_time_scale(scale: float) -> Dictionary:
	return {
		"type": ACTION_SET_TIME_SCALE,
		"payload": {
			"scale": scale
		}
	}

static func set_show_collision_shapes(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SHOW_COLLISION_SHAPES,
		"payload": {
			"enabled": enabled
		}
	}

static func set_show_spawn_points(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SHOW_SPAWN_POINTS,
		"payload": {
			"enabled": enabled
		}
	}

static func set_show_trigger_zones(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SHOW_TRIGGER_ZONES,
		"payload": {
			"enabled": enabled
		}
	}

static func set_show_entity_labels(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SHOW_ENTITY_LABELS,
		"payload": {
			"enabled": enabled
		}
	}
