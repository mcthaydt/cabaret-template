extends RefCounted
class_name PhysicsSelectors

## Physics state selectors for gameplay slice
##
## Phase 16: Created for full project integration
## Used by physics systems to read state

## Get gravity scale
static func get_gravity_scale(state: Dictionary) -> float:
	return state.get("gameplay", {}).get("gravity_scale", 1.0)

## Get is_on_floor flag
static func get_is_on_floor(state: Dictionary) -> bool:
	return state.get("gameplay", {}).get("is_on_floor", false)

## Get velocity
static func get_velocity(state: Dictionary) -> Vector3:
	return state.get("gameplay", {}).get("velocity", Vector3.ZERO)

## Get position
static func get_position(state: Dictionary) -> Vector3:
	return state.get("gameplay", {}).get("position", Vector3.ZERO)

## Get rotation
static func get_rotation(state: Dictionary) -> Vector3:
	return state.get("gameplay", {}).get("rotation", Vector3.ZERO)

## Get is_moving flag
static func get_is_moving(state: Dictionary) -> bool:
	return state.get("gameplay", {}).get("is_moving", false)
