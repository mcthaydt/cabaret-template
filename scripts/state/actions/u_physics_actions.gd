extends Node
class_name U_PhysicsActions

## Physics action creators for gameplay slice
##
## Phase 16: Created for full project integration
## Used by physics systems to dispatch state changes

const ActionRegistry = preload("res://scripts/state/core/action_registry.gd")

## Update gravity scale (for low-gravity zones, etc.)
static func update_gravity_scale(gravity_scale: float) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_GRAVITY_SCALE", {
		"gravity_scale": gravity_scale
	})

## Update floor detection state
static func update_floor_state(is_on_floor: bool) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_FLOOR_STATE", {
		"is_on_floor": is_on_floor
	})

## Update velocity
static func update_velocity(velocity: Vector3) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_VELOCITY", {
		"velocity": velocity
	})

## Update position
static func update_position(position: Vector3) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_POSITION", {
		"position": position
	})

## Update rotation
static func update_rotation(rotation: Vector3) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_ROTATION", {
		"rotation": rotation
	})

## Update is_moving flag
static func update_is_moving(is_moving: bool) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_IS_MOVING", {
		"is_moving": is_moving
	})
