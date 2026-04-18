extends RefCounted
class_name U_AIWorldStateBuilder

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/ecs/components/c_health_component.gd")

const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const DETECTION_COMPONENT_TYPE := C_DETECTION_COMPONENT.COMPONENT_TYPE
const NEEDS_COMPONENT_TYPE := C_NEEDS_COMPONENT.COMPONENT_TYPE
const HEALTH_COMPONENT_TYPE := C_HEALTH_COMPONENT.COMPONENT_TYPE

func build(entity_query: Object) -> Dictionary:
	var world_state: Dictionary = {}
	if entity_query == null:
		return world_state

	var components: Dictionary = _resolve_components(entity_query)
	_write_brain_state(world_state, components)
	_write_movement_state(world_state, components)
	_write_detection_state(world_state, components)
	_write_needs_state(world_state, components)
	_write_health_state(world_state, components)
	return world_state

func _resolve_components(entity_query: Object) -> Dictionary:
	if entity_query.has_method("get_all_components"):
		var components_variant: Variant = entity_query.call("get_all_components")
		if components_variant is Dictionary:
			return (components_variant as Dictionary).duplicate(true)
	return {}

func _write_brain_state(world_state: Dictionary, components: Dictionary) -> void:
	var brain_variant: Variant = components.get(BRAIN_COMPONENT_TYPE, null)
	if brain_variant == null or not (brain_variant is C_AIBrainComponent):
		return
	var brain: C_AIBrainComponent = brain_variant as C_AIBrainComponent
	world_state[&"active_goal_id"] = brain.active_goal_id
	world_state[&"evaluation_timer"] = brain.evaluation_timer

func _write_movement_state(world_state: Dictionary, components: Dictionary) -> void:
	var movement_variant: Variant = components.get(MOVEMENT_COMPONENT_TYPE, null)
	if movement_variant == null or not (movement_variant is C_MovementComponent):
		return
	var movement: C_MovementComponent = movement_variant as C_MovementComponent
	var velocity: Vector2 = movement.get_horizontal_dynamics_velocity()
	world_state[&"movement_speed"] = velocity.length()

func _write_detection_state(world_state: Dictionary, components: Dictionary) -> void:
	var detection_variant: Variant = components.get(DETECTION_COMPONENT_TYPE, null)
	if detection_variant == null or not (detection_variant is C_DetectionComponent):
		return
	var detection: C_DetectionComponent = detection_variant as C_DetectionComponent
	world_state[&"is_player_in_range"] = detection.is_player_in_range
	world_state[&"last_detected_player_entity_id"] = detection.last_detected_player_entity_id

func _write_needs_state(world_state: Dictionary, components: Dictionary) -> void:
	var needs_variant: Variant = components.get(NEEDS_COMPONENT_TYPE, null)
	if needs_variant == null or not (needs_variant is C_NeedsComponent):
		return
	var needs: C_NeedsComponent = needs_variant as C_NeedsComponent
	world_state[&"hunger"] = needs.hunger

func _write_health_state(world_state: Dictionary, components: Dictionary) -> void:
	var health_variant: Variant = components.get(HEALTH_COMPONENT_TYPE, null)
	if health_variant == null or not (health_variant is C_HealthComponent):
		return
	var health: C_HealthComponent = health_variant as C_HealthComponent
	world_state[&"current_health"] = health.current_health
	world_state[&"max_health"] = health.max_health
