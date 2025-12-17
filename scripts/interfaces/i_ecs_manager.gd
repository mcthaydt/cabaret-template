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
