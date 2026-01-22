extends Node
class_name I_ECSManager

## Minimal interface for M_ECSManager
##
## Systems only need these core query/registration methods,
## not entity tracking, metrics, or time provider internals.
##
## Phase 10B-8 (T142a): Created to enable dependency injection and testing
##
## Implementations:
## - M_ECSManager (production)
## - MockECSManager (testing)

## Get all components of a specific type
##
## @param component_type: StringName identifying the component type
## @return Array: All registered components of this type (duplicated)
func get_components(_component_type: StringName) -> Array:
	push_error("I_ECSManager.get_components not implemented")
	return []

## Query entities with required/optional component types
##
## @param required: Array[StringName] of component types entity must have
## @param optional: Array[StringName] of component types to include if present
## @return Array[U_EntityQuery]: Matching entities with their components
func query_entities(_required: Array[StringName], _optional: Array[StringName] = []) -> Array:
	push_error("I_ECSManager.query_entities not implemented")
	return []

## Get all components attached to an entity
##
## @param entity: Node representing the entity root
## @return Dictionary: Map of component_type → component instance
func get_components_for_entity(_entity: Node) -> Dictionary:
	push_error("I_ECSManager.get_components_for_entity not implemented")
	return {}

## Register a component with the manager
##
## @param component: BaseECSComponent instance to register
func register_component(_component: BaseECSComponent) -> void:
	push_error("I_ECSManager.register_component not implemented")

## Register a system with the manager
##
## @param system: BaseECSSystem instance to register
func register_system(_system: BaseECSSystem) -> void:
	push_error("I_ECSManager.register_system not implemented")

## Cache entity root for a node
##
## @param node: Node to cache entity for
## @param entity: Entity root to associate with the node
func cache_entity_for_node(_node: Node, _entity: Node) -> void:
	push_error("I_ECSManager.cache_entity_for_node not implemented")

## Get cached entity root for a node
##
## @param node: Node to look up cached entity for
## @return Node: Cached entity root, or null if not cached
func get_cached_entity_for(_node: Node) -> Node:
	push_error("I_ECSManager.get_cached_entity_for not implemented")
	return null

## Update entity tags in the manager's tag index
##
## @param entity: Entity node whose tags should be re-indexed
func update_entity_tags(_entity: Node) -> void:
	push_error("I_ECSManager.update_entity_tags not implemented")

## Mark systems as dirty to trigger re-sorting
##
## Used when system priority changes at runtime
func mark_systems_dirty() -> void:
	push_error("I_ECSManager.mark_systems_dirty not implemented")
