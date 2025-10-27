extends RefCounted
class_name PhysicsSelectors

## Global physics settings selectors
##
## Phase 16: Entity Coordination Pattern
## For per-entity physics (position, velocity, etc.), use EntitySelectors
## This class only contains global physics settings (gravity_scale, etc.)

## Get global gravity scale (affects all entities)
static func get_gravity_scale(state: Dictionary) -> float:
	return state.get("gameplay", {}).get("gravity_scale", 1.0)
