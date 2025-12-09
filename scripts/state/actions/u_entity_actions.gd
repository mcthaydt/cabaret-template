extends RefCounted
class_name U_EntityActions

## Entity coordination action creators
##
## Phase 16: Entity Coordination Pattern
## Components = source of truth, State = coordination layer
## See: redux-state-store-entity-coordination-pattern.md

const ACTION_UPDATE_ENTITY_SNAPSHOT := StringName("gameplay/UPDATE_ENTITY_SNAPSHOT")
const ACTION_REMOVE_ENTITY := StringName("gameplay/REMOVE_ENTITY")

## Static initializer - register actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_UPDATE_ENTITY_SNAPSHOT)
	U_ActionRegistry.register_action(ACTION_REMOVE_ENTITY)

## Update entity snapshot in state (for coordination/visibility)
## entity_id: Unique identifier (e.g., "player", "enemy_goblin_1") - accepts String or StringName
## snapshot: Dictionary with entity data (position, velocity, rotation, etc.)
static func update_entity_snapshot(entity_id: Variant, snapshot: Dictionary) -> Dictionary:
	# Convert StringName to String for dictionary keys
	var id_string := String(entity_id) if entity_id is StringName else str(entity_id)
	return {
		"type": ACTION_UPDATE_ENTITY_SNAPSHOT,
		"payload": {
			"entity_id": id_string,
			"snapshot": snapshot
		}
	}

## Remove entity from state (on despawn)
## entity_id: Unique identifier - accepts String or StringName
static func remove_entity(entity_id: Variant) -> Dictionary:
	# Convert StringName to String for dictionary keys
	var id_string := String(entity_id) if entity_id is StringName else str(entity_id)
	return {
		"type": ACTION_REMOVE_ENTITY,
		"payload": {
			"entity_id": id_string
		}
	}

## Convenience: Update entity physics snapshot
## entity_id: accepts String or StringName
static func update_entity_physics(entity_id: Variant, position: Vector3, velocity: Vector3, rotation: Vector3, is_on_floor: bool, is_moving: bool) -> Dictionary:
	return update_entity_snapshot(entity_id, {
		"position": position,
		"velocity": velocity,
		"rotation": rotation,
		"is_on_floor": is_on_floor,
		"is_moving": is_moving
	})
