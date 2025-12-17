extends I_ECSManager
class_name MockECSManager

## Functional mock for M_ECSManager
##
## Tracks registered components by type and supports query operations.
## Provides test helpers for pre-populating components and verifying registrations.
##
## Phase 10B-8 (T142b): Created to enable isolated system testing
##
## Test helpers:
## - add_component_to_entity(entity, component): Pre-register components
## - clear_all_components(): Reset component registry
## - get_registered_systems(): Verify system registration
## - reset(): Clear all state

const U_ENTITY_QUERY := preload("res://scripts/ecs/u_entity_query.gd")

var _components: Dictionary = {}  # StringName → Array[BaseECSComponent]
var _entity_components: Dictionary = {}  # Node → Dictionary[StringName, BaseECSComponent]
var _registered_systems: Array[BaseECSSystem] = []

func get_components(component_type: StringName) -> Array:
	if not _components.has(component_type):
		return []
	var result: Array = _components[component_type]
	return result.duplicate()

func query_entities(required: Array[StringName], optional: Array[StringName] = []) -> Array:
	var results: Array[U_EntityQuery] = []

	if required.is_empty():
		return results

	# Find entities that have ALL required components
	for entity in _entity_components.keys():
		var entity_comps: Dictionary = _entity_components[entity]

		var has_all_required := true
		for req_type in required:
			if not entity_comps.has(req_type):
				has_all_required = false
				break

		if not has_all_required:
			continue

		# Build query result
		var query_comps: Dictionary = {}
		for req_type in required:
			query_comps[req_type] = entity_comps[req_type]
		for opt_type in optional:
			if entity_comps.has(opt_type):
				query_comps[opt_type] = entity_comps[opt_type]

		var query := U_ENTITY_QUERY.new()
		query.entity = entity
		query.components = query_comps
		results.append(query)

	return results

func get_components_for_entity(entity: Node) -> Dictionary:
	if not _entity_components.has(entity):
		return {}
	return _entity_components[entity].duplicate(true)

func register_component(component: BaseECSComponent) -> void:
	if component == null:
		return

	var type_name: StringName = component.get_component_type()
	if not _components.has(type_name):
		_components[type_name] = []

	var existing: Array = _components[type_name]
	if not existing.has(component):
		existing.append(component)

	# Track by entity
	var entity := _find_entity_root(component)
	if entity != null:
		if not _entity_components.has(entity):
			_entity_components[entity] = {}
		_entity_components[entity][type_name] = component

func register_system(system: BaseECSSystem) -> void:
	if system != null and not _registered_systems.has(system):
		_registered_systems.append(system)

## Test helpers

## Pre-register a component for an entity
func add_component_to_entity(entity: Node, component: BaseECSComponent) -> void:
	register_component(component)

## Clear all registered components
func clear_all_components() -> void:
	_components.clear()
	_entity_components.clear()

## Get all registered systems for verification
func get_registered_systems() -> Array[BaseECSSystem]:
	return _registered_systems.duplicate()

## Reset all state
func reset() -> void:
	_components.clear()
	_entity_components.clear()
	_registered_systems.clear()

## Find the entity root for a component
func _find_entity_root(component: BaseECSComponent) -> Node:
	var current: Node = component.get_parent()
	while current != null:
		# Check for E_ prefix (entity naming convention)
		if current.name.begins_with("E_"):
			return current
		# Check for ecs_entity group membership
		if current.is_in_group("ecs_entity"):
			return current
		current = current.get_parent()
	# Fallback to immediate parent
	return component.get_parent()
