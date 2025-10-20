@icon("res://editor_icons/manager.svg")
extends Node
class_name M_ECSManager

signal component_added(component_type: StringName, component: ECSComponent)
signal component_removed(component_type: StringName, component: ECSComponent)

const META_ENTITY_ROOT := StringName("_ecs_entity_root")
const META_ENTITY_TRACKED := StringName("_ecs_tracked_entity")

var _components: Dictionary = {}
var _systems: Array[ECSSystem] = []
var _entity_component_map: Dictionary = {}
var _query_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("ecs_manager")

func _exit_tree() -> void:
	if is_in_group("ecs_manager"):
		remove_from_group("ecs_manager")

func register_component(component: ECSComponent) -> void:
	if component == null:
		push_warning("Attempted to register a null component")
		return

	var type_name: StringName = component.get_component_type()
	if not _components.has(type_name):
		_components[type_name] = []

	var existing: Array = _components[type_name]
	if existing.has(component):
		return

	existing.append(component)
	_track_component(component, type_name)

	component.on_registered(self)
	component_added.emit(type_name, component)

func unregister_component(component: ECSComponent) -> void:
	if component == null:
		return

	var type_name: StringName = component.get_component_type()
	if not _components.has(type_name):
		return

	var existing: Array = _components[type_name]
	if not existing.has(component):
		return

	existing.erase(component)
	component_removed.emit(type_name, component)

	if existing.is_empty():
		_components.erase(type_name)

	_untrack_component(component, type_name)

func get_components(component_type: StringName) -> Array:
	if not _components.has(component_type):
		return []

	var existing: Array = _components[component_type]
	var filtered: Array = []
	for entry in existing:
		if entry != null:
			filtered.append(entry)

	if filtered.size() != existing.size():
		if filtered.is_empty():
			_components.erase(component_type)
			return []
		_components[component_type] = filtered

	return filtered.duplicate()

func get_systems() -> Array:
	return _systems.duplicate()

func get_components_for_entity(entity: Node) -> Dictionary:
	if entity == null:
		return {}
	if not _entity_component_map.has(entity):
		return {}
	return (_entity_component_map[entity] as Dictionary).duplicate(true)

func register_system(system: ECSSystem) -> void:
	if system == null:
		push_warning("Attempted to register a null system")
		return

	if _systems.has(system):
		return

	_systems.append(system)
	system.configure(self)

func query_entities(required: Array[StringName], optional: Array[StringName] = []) -> Array:
	var results: Array[EntityQuery] = []
	if required.is_empty():
		push_warning("M_ECSManager.query_entities called without required component types")
		return results

	var candidate_type := _get_smallest_component_type(required)
	if candidate_type == StringName():
		return results

	var key := _make_query_cache_key(required, optional)
	if _query_cache.has(key):
		return _duplicate_query_results(_query_cache[key])

	var candidate_components := get_components(candidate_type)
	if candidate_components.is_empty():
		return results

	var seen_entities: Dictionary = {}
	for component in candidate_components:
		var entity := _get_entity_for_component(component)
		if entity == null:
			continue
		if seen_entities.has(entity):
			continue
		if not _entity_component_map.has(entity):
			continue

		var entity_components: Dictionary = _entity_component_map[entity]
		var has_all_required := true
		for required_type in required:
			if not entity_components.has(required_type):
				has_all_required = false
				break
		if not has_all_required:
			continue

		var query_components: Dictionary = {}
		for required_type in required:
			query_components[required_type] = entity_components[required_type]
		for optional_type in optional:
			if entity_components.has(optional_type):
				query_components[optional_type] = entity_components[optional_type]

		var query := EntityQuery.new()
		query.entity = entity
		query.components = query_components
		results.append(query)
		seen_entities[entity] = true

	_query_cache[key] = results

	return results.duplicate()

func _track_component(component: ECSComponent, type_name: StringName) -> void:
	var entity := _get_entity_for_component(component)
	if entity == null:
		return

	component.set_meta(META_ENTITY_ROOT, entity)

	if not _entity_component_map.has(entity):
		_entity_component_map[entity] = {}
		if not entity.has_meta(META_ENTITY_TRACKED):
			entity.set_meta(META_ENTITY_TRACKED, true)
			entity.connect("tree_exited", Callable(self, "_on_tracked_entity_exited").bind(entity), Object.CONNECT_ONE_SHOT)

	var tracked_components: Dictionary = _entity_component_map[entity]
	tracked_components[type_name] = component
	_entity_component_map[entity] = tracked_components
	_invalidate_query_cache()

func _untrack_component(component: ECSComponent, type_name: StringName) -> void:
	var entity: Node = null
	if component.has_meta(META_ENTITY_ROOT):
		entity = component.get_meta(META_ENTITY_ROOT) as Node
		component.remove_meta(META_ENTITY_ROOT)

	if entity == null:
		entity = _find_entity_for_component(component)

	if entity == null:
		return

	if not _entity_component_map.has(entity):
		return

	var tracked_components: Dictionary = _entity_component_map[entity]
	if tracked_components.get(type_name) == component:
		tracked_components.erase(type_name)

	if tracked_components.is_empty():
		_entity_component_map.erase(entity)
	else:
		_entity_component_map[entity] = tracked_components
	_invalidate_query_cache()

func _get_entity_for_component(component: ECSComponent, warn_on_missing: bool = true) -> Node:
	var current := component.get_parent()
	while current != null:
		if current.name.begins_with("E_"):
			return current
		current = current.get_parent()

	if warn_on_missing:
		push_error("M_ECSManager: Component %s has no entity root ancestor" % component.name)
	return null

func _find_entity_for_component(component: ECSComponent) -> Node:
	for entity in _entity_component_map.keys():
		var tracked_components: Dictionary = _entity_component_map[entity]
		if tracked_components.values().has(component):
			return entity
	return null

func _on_tracked_entity_exited(entity: Node) -> void:
	_entity_component_map.erase(entity)
	if entity.has_meta(META_ENTITY_TRACKED):
		entity.remove_meta(META_ENTITY_TRACKED)
	_invalidate_query_cache()

func _get_smallest_component_type(required: Array[StringName]) -> StringName:
	if required.is_empty():
		return StringName()

	var smallest_type := required[0]
	var smallest_count := get_components(smallest_type).size()

	for index in range(1, required.size()):
		var candidate_type := required[index]
		var candidate_count := get_components(candidate_type).size()
		if candidate_count < smallest_count:
			smallest_count = candidate_count
			smallest_type = candidate_type

	return smallest_type

func _make_query_cache_key(required: Array, optional: Array) -> String:
	var required_names: Array = []
	for type_name in required:
		required_names.append(String(type_name))
	required_names.sort()

	var optional_names: Array = []
	for type_name in optional:
		optional_names.append(String(type_name))
	optional_names.sort()

	return "req:%s|opt:%s" % [",".join(required_names), ",".join(optional_names)]

func _duplicate_query_results(results: Array) -> Array:
	return results.duplicate()

func _invalidate_query_cache() -> void:
	if _query_cache.is_empty():
		return
	_query_cache.clear()
