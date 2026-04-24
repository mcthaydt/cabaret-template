extends RefCounted
class_name U_AIWorldStateBuilder

const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/core/ecs/components/c_health_component.gd")

const BRAIN_COMPONENT_TYPE := StringName("C_AIBrainComponent")
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const DETECTION_COMPONENT_TYPE := StringName("C_DetectionComponent")
const NEEDS_COMPONENT_TYPE := StringName("C_NeedsComponent")
const HEALTH_COMPONENT_TYPE := C_HEALTH_COMPONENT.COMPONENT_TYPE
const INVENTORY_COMPONENT_TYPE := StringName("C_InventoryComponent")
const RESOURCE_NODE_COMPONENT_TYPE := StringName("C_ResourceNodeComponent")
const BUILD_SITE_COMPONENT_TYPE := StringName("C_BuildSiteComponent")

func build(entity_source: Variant) -> Dictionary:
	var world_state: Dictionary = {}
	if entity_source == null:
		return world_state

	var components: Dictionary = _resolve_components(entity_source)
	_write_brain_state(world_state, components)
	_write_movement_state(world_state, components)
	_write_detection_state(world_state, components)
	_write_needs_state(world_state, components)
	_write_health_state(world_state, components)
	_write_inventory_state(world_state, components)
	_write_resource_node_state(world_state, components)
	_write_build_site_state(world_state, components)
	return world_state

func _resolve_components(entity_source: Variant) -> Dictionary:
	if entity_source is Dictionary:
		var context: Dictionary = entity_source as Dictionary
		var context_components: Variant = _get_dict_value_string_or_name(context, "components")
		if context_components is Dictionary:
			return (context_components as Dictionary).duplicate(true)
		return context.duplicate(true)

	if entity_source is Object:
		var entity_query: Object = entity_source as Object
		if entity_query.has_method("get_all_components"):
			var components_variant: Variant = entity_query.call("get_all_components")
			if components_variant is Dictionary:
				return (components_variant as Dictionary).duplicate(true)
	return {}

func _get_dict_value_string_or_name(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)
	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)
	return null

func _write_brain_state(world_state: Dictionary, components: Dictionary) -> void:
	var brain: Object = components.get(BRAIN_COMPONENT_TYPE, null)
	if brain == null:
		return
	world_state[&"active_goal_id"] = brain.get("active_goal_id")
	world_state[&"evaluation_timer"] = brain.get("evaluation_timer")

func _write_movement_state(world_state: Dictionary, components: Dictionary) -> void:
	var movement_variant: Variant = components.get(MOVEMENT_COMPONENT_TYPE, null)
	if movement_variant == null or not (movement_variant is C_MovementComponent):
		return
	var movement: C_MovementComponent = movement_variant as C_MovementComponent
	var velocity: Vector2 = movement.get_horizontal_dynamics_velocity()
	world_state[&"movement_speed"] = velocity.length()

func _write_detection_state(world_state: Dictionary, components: Dictionary) -> void:
	var detection: Object = components.get(DETECTION_COMPONENT_TYPE, null)
	if detection == null:
		return
	world_state[&"is_player_in_range"] = detection.get("is_player_in_range")
	world_state[&"last_detected_player_entity_id"] = detection.get("last_detected_player_entity_id")

func _write_needs_state(world_state: Dictionary, components: Dictionary) -> void:
	var needs: Object = components.get(NEEDS_COMPONENT_TYPE, null)
	if needs == null:
		return
	world_state[&"hunger"] = needs.get("hunger")

func _write_health_state(world_state: Dictionary, components: Dictionary) -> void:
	var health_variant: Variant = components.get(HEALTH_COMPONENT_TYPE, null)
	if health_variant == null or not (health_variant is C_HealthComponent):
		return
	var health: C_HealthComponent = health_variant as C_HealthComponent
	world_state[&"current_health"] = health.current_health
	world_state[&"max_health"] = health.max_health

func _write_inventory_state(world_state: Dictionary, components: Dictionary) -> void:
	var inventory: Object = components.get(INVENTORY_COMPONENT_TYPE, null)
	if inventory == null:
		return
	world_state[&"inventory_fill_ratio"] = inventory.get("fill_ratio")

func _write_resource_node_state(world_state: Dictionary, components: Dictionary) -> void:
	var resource_node: Object = components.get(RESOURCE_NODE_COMPONENT_TYPE, null)
	if resource_node == null:
		return
	world_state[&"resource_current_amount"] = resource_node.get("current_amount")
	world_state[&"resource_available"] = resource_node.call("is_available")

func _write_build_site_state(world_state: Dictionary, components: Dictionary) -> void:
	var build_site: Object = components.get(BUILD_SITE_COMPONENT_TYPE, null)
	if build_site == null:
		return
	world_state[&"materials_ready"] = build_site.get("materials_ready")
	world_state[&"build_completed"] = build_site.get("completed")