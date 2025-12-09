extends RefCounted
class_name U_EntitySelectors

## Entity coordination selectors
##
## Phase 16: Entity Coordination Pattern
## Read entity snapshots for coordination (AI, UI, debugging)
## See: redux-state-store-entity-coordination-pattern.md

## Get all entity snapshots
static func get_all_entities(state: Dictionary) -> Dictionary:
	return state.get("gameplay", {}).get("entities", {})

## Get specific entity snapshot
## entity_id: accepts String or StringName
static func get_entity(state: Dictionary, entity_id: Variant) -> Dictionary:
	# Convert StringName to String for dictionary lookup
	var id_string := String(entity_id) if entity_id is StringName else str(entity_id)
	return get_all_entities(state).get(id_string, {})

## Get entity position
## entity_id: accepts String or StringName
static func get_entity_position(state: Dictionary, entity_id: Variant) -> Vector3:
	return get_entity(state, entity_id).get("position", Vector3.ZERO)

## Get entity velocity
## entity_id: accepts String or StringName
static func get_entity_velocity(state: Dictionary, entity_id: Variant) -> Vector3:
	return get_entity(state, entity_id).get("velocity", Vector3.ZERO)

## Get entity rotation
## entity_id: accepts String or StringName
static func get_entity_rotation(state: Dictionary, entity_id: Variant) -> Vector3:
	return get_entity(state, entity_id).get("rotation", Vector3.ZERO)

## Check if entity is on floor
## entity_id: accepts String or StringName
static func is_entity_on_floor(state: Dictionary, entity_id: Variant) -> bool:
	return get_entity(state, entity_id).get("is_on_floor", false)

## Check if entity is moving
## entity_id: accepts String or StringName
static func is_entity_moving(state: Dictionary, entity_id: Variant) -> bool:
	return get_entity(state, entity_id).get("is_moving", false)

## Get entity type (player, enemy, npc, etc.)
## entity_id: accepts String or StringName
static func get_entity_type(state: Dictionary, entity_id: Variant) -> String:
	return get_entity(state, entity_id).get("entity_type", "unknown")

## Get entity health
## entity_id: accepts String or StringName
static func get_entity_health(state: Dictionary, entity_id: Variant) -> float:
	var entity: Dictionary = get_entity(state, entity_id)
	if entity.has("health"):
		return float(entity.get("health"))

	var gameplay: Dictionary = state.get("gameplay", {})
	var player_id: String = String(gameplay.get("player_entity_id", "E_Player"))
	# Convert entity_id to String for comparison
	var id_string := String(entity_id) if entity_id is StringName else str(entity_id)
	if id_string == player_id:
		return float(gameplay.get("player_health", 0.0))

	return float(entity.get("health", gameplay.get("player_health", 0.0)))

## Get entity max health (player fallback)
## entity_id: accepts String or StringName
static func get_entity_max_health(state: Dictionary, entity_id: Variant) -> float:
	var entity: Dictionary = get_entity(state, entity_id)
	if entity.has("max_health"):
		return float(entity.get("max_health"))

	var gameplay: Dictionary = state.get("gameplay", {})
	var player_id: String = String(gameplay.get("player_entity_id", "E_Player"))
	# Convert entity_id to String for comparison
	var id_string := String(entity_id) if entity_id is StringName else str(entity_id)
	if id_string == player_id:
		return float(gameplay.get("player_max_health", 0.0))

	return float(entity.get("max_health", 0.0))

## Get all entities of a specific type
static func get_entities_by_type(state: Dictionary, entity_type: String) -> Array:
	var result: Array = []
	var all_entities: Dictionary = get_all_entities(state)
	for entity_id in all_entities.keys():
		var entity: Dictionary = all_entities[entity_id]
		if entity.get("entity_type", "") == entity_type:
			result.append({
				"id": entity_id,
				"data": entity
			})
	return result

## Get player entity ID (convenience)
static func get_player_entity_id(state: Dictionary) -> String:
	var entities: Array = get_entities_by_type(state, "player")
	if entities.size() > 0:
		return entities[0]["id"]
	return state.get("gameplay", {}).get("player_entity_id", "E_Player")

## Get player position (convenience)
static func get_player_position(state: Dictionary) -> Vector3:
	var player_id: String = get_player_entity_id(state)
	if player_id.is_empty():
		return Vector3.ZERO
	return get_entity_position(state, player_id)

## Get player velocity (convenience)
static func get_player_velocity(state: Dictionary) -> Vector3:
	var player_id: String = get_player_entity_id(state)
	if player_id.is_empty():
		return Vector3.ZERO
	return get_entity_velocity(state, player_id)

## Get all enemy entities
static func get_all_enemies(state: Dictionary) -> Array:
	return get_entities_by_type(state, "enemy")

## Get entities within radius of a point
static func get_entities_within_radius(state: Dictionary, center: Vector3, radius: float) -> Array:
	var result: Array = []
	var all_entities: Dictionary = get_all_entities(state)
	var radius_squared: float = radius * radius
	
	for entity_id in all_entities.keys():
		var entity: Dictionary = all_entities[entity_id]
		var entity_pos: Vector3 = entity.get("position", Vector3.ZERO)
		var distance_squared: float = center.distance_squared_to(entity_pos)
		
		if distance_squared <= radius_squared:
			result.append({
				"id": entity_id,
				"data": entity,
				"distance": sqrt(distance_squared)
			})
	
	return result
