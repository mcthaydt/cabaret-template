@icon("res://resources/editor_icons/manager.svg")
extends I_ECSManager
class_name M_ECSManager

signal component_added(component_type: StringName, component: BaseECSComponent)
signal component_removed(component_type: StringName, component: BaseECSComponent)

const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ECS_QUERY_METRICS := preload("res://scripts/utils/ecs/u_ecs_query_metrics.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_ECS_ENTITY := preload("res://scripts/interfaces/i_ecs_entity.gd")
const PROJECT_SETTING_QUERY_METRICS_ENABLED := "ecs/debug/query_metrics_enabled"
const PROJECT_SETTING_QUERY_METRICS_CAPACITY := "ecs/debug/query_metrics_capacity"

const EVENT_ENTITY_REGISTERED := StringName("entity_registered")
const EVENT_ENTITY_UNREGISTERED := StringName("entity_unregistered")

var _components: Dictionary = {}
var _systems: Array[BaseECSSystem] = []
var _sorted_systems: Array[BaseECSSystem] = []
var _systems_dirty: bool = true
var _entity_component_map: Dictionary = {}
var _node_entity_cache: Dictionary = {}  # instance_id → entity root
var _query_cache: Dictionary = {}
var _time_provider: Callable = Callable(U_ECS_UTILS, "get_current_time")
var _query_metrics_helper := U_ECS_QUERY_METRICS.new()

# Entity ID and tagging support
var _entities_by_id: Dictionary = {}  # StringName → Node
var _entities_by_tag: Dictionary = {}  # StringName → Array[Node]
var _registered_entities: Dictionary = {}  # Node → StringName (entity_id)
var _tracked_entities: Dictionary = {}  # Node → bool (tree_exited connection)

@export var query_metrics_enabled: bool:
	get:
		return _query_metrics_helper.get_query_metrics_enabled()
	set(value):
		_query_metrics_helper.set_query_metrics_enabled(value)

@export var query_metrics_capacity: int:
	get:
		return _query_metrics_helper.get_query_metrics_capacity()
	set(value):
		_query_metrics_helper.set_query_metrics_capacity(value)

func _ready() -> void:
	var service_name := StringName("ecs_manager")
	var existing := U_SERVICE_LOCATOR.try_get_service(service_name)
	if existing != self:
		U_SERVICE_LOCATOR.register(service_name, self)
	set_physics_process(true)
	_initialize_query_metric_settings()

func _initialize_query_metric_settings() -> void:
	var default_enabled: bool = OS.is_debug_build() or Engine.is_editor_hint()
	var configured_enabled: bool = default_enabled
	if ProjectSettings.has_setting(PROJECT_SETTING_QUERY_METRICS_ENABLED):
		var stored_enabled: Variant = ProjectSettings.get_setting(PROJECT_SETTING_QUERY_METRICS_ENABLED, default_enabled)
		if stored_enabled is bool:
			configured_enabled = stored_enabled
		elif typeof(stored_enabled) == TYPE_INT:
			configured_enabled = bool(stored_enabled)
	query_metrics_enabled = configured_enabled

	if ProjectSettings.has_setting(PROJECT_SETTING_QUERY_METRICS_CAPACITY):
		var default_capacity: int = _query_metrics_helper.get_query_metrics_capacity()
		var stored_capacity: int = int(ProjectSettings.get_setting(PROJECT_SETTING_QUERY_METRICS_CAPACITY, default_capacity))
		query_metrics_capacity = stored_capacity

func register_component(component: BaseECSComponent) -> void:
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

func unregister_component(component: BaseECSComponent) -> void:
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
	_ensure_systems_sorted()
	return _sorted_systems.duplicate()

func get_components_for_entity(entity: Node) -> Dictionary:
	if entity == null:
		return {}
	if not _entity_component_map.has(entity):
		return {}
	return (_entity_component_map[entity] as Dictionary).duplicate(true)

func get_cached_entity_for(node: Node) -> Node:
	if node == null:
		return null
	return _node_entity_cache.get(node.get_instance_id(), null) as Node

func cache_entity_for_node(node: Node, entity: Node) -> void:
	if node == null or entity == null:
		return
	_node_entity_cache[node.get_instance_id()] = entity

func set_time_provider(provider: Callable) -> void:
	if provider == Callable():
		_time_provider = Callable(U_ECS_UTILS, "get_current_time")
		return
	if not provider.is_valid():
		_time_provider = Callable(U_ECS_UTILS, "get_current_time")
		return
	_time_provider = provider

func reset_time_provider() -> void:
	_time_provider = Callable(U_ECS_UTILS, "get_current_time")

func get_query_metrics() -> Array:
	return _query_metrics_helper.get_query_metrics()

func clear_query_metrics() -> void:
	_query_metrics_helper.clear_query_metrics()

func set_query_metrics_enabled_runtime(enabled: bool) -> void:
	query_metrics_enabled = enabled

func set_query_metrics_capacity_runtime(capacity: int) -> void:
	query_metrics_capacity = capacity

func register_system(system: BaseECSSystem) -> void:
	if system == null:
		push_warning("Attempted to register a null system")
		return

	if _systems.has(system):
		return

	_systems.append(system)
	system.configure(self)
	if system.has_method("set_physics_process"):
		system.set_physics_process(false)
	mark_systems_dirty()

func query_entities(required: Array[StringName], optional: Array[StringName] = []) -> Array:
	var results: Array[U_EntityQuery] = []
	if required.is_empty():
		push_warning("M_ECSManager.query_entities called without required component types")
		return results

	var candidate_type := _get_smallest_component_type(required)
	if candidate_type == StringName():
		return results

	var key := _make_query_cache_key(required, optional)
	var start_time: float = _get_current_time()

	if _query_cache.has(key):
		var cached_results: Array = _query_cache[key]
		_query_metrics_helper.record_query_metrics(
			key,
			required,
			optional,
			cached_results.size(),
			0.0,
			true,
			start_time
		)
		return _duplicate_query_results(cached_results)

	var candidate_components := get_components(candidate_type)
	if candidate_components.is_empty():
		var no_result_time: float = _get_current_time()
		var no_result_duration: float = max(no_result_time - start_time, 0.0)
		_query_metrics_helper.record_query_metrics(
			key,
			required,
			optional,
			0,
			no_result_duration,
			false,
			no_result_time
		)
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

		var query := U_EntityQuery.new()
		query.entity = entity
		query.components = query_components
		results.append(query)
		seen_entities[entity] = true

	_query_cache[key] = results
	var end_time: float = _get_current_time()
	var duration: float = max(end_time - start_time, 0.0)
	_query_metrics_helper.record_query_metrics(
		key,
		required,
		optional,
		results.size(),
		duration,
		false,
		end_time
	)

	return results.duplicate()

## Registers an entity with the ECS manager.
## Handles duplicate IDs by appending instance ID suffix.
## Publishes entity_registered event via U_ECSEventBus.
func register_entity(entity: Node) -> void:
	if entity == null:
		return
	if _registered_entities.has(entity):
		return

	var entity_id := _get_entity_id(entity)

	# Handle duplicate IDs by appending instance ID suffix
	if _entities_by_id.has(entity_id):
		var new_id := StringName("%s_%d" % [String(entity_id), entity.get_instance_id()])
		print_verbose("M_ECSManager: Duplicate entity ID '%s' - renamed to '%s'" % [String(entity_id), String(new_id)])
		entity_id = new_id
		var typed_entity := entity as I_ECSEntity
		if typed_entity != null:
			typed_entity.set_entity_id(entity_id)

	_entities_by_id[entity_id] = entity
	_registered_entities[entity] = entity_id
	_index_entity_tags(entity)
	_node_entity_cache[entity.get_instance_id()] = entity
	_ensure_entity_exit_tracking(entity)

	U_ECS_EVENT_BUS.publish(EVENT_ENTITY_REGISTERED, {
		"entity_id": entity_id,
		"entity": entity
	})

## Unregisters an entity from the ECS manager.
## Publishes entity_unregistered event via U_ECSEventBus.
func unregister_entity(entity: Node) -> void:
	if entity == null:
		return
	if not _registered_entities.has(entity):
		return

	var entity_id: StringName = _registered_entities[entity]
	_entities_by_id.erase(entity_id)
	_registered_entities.erase(entity)
	_unindex_entity_tags(entity)
	_node_entity_cache.erase(entity.get_instance_id())
	_tracked_entities.erase(entity)

	U_ECS_EVENT_BUS.publish(EVENT_ENTITY_UNREGISTERED, {
		"entity_id": entity_id,
		"entity": entity
	})

## Returns the entity with the given ID, or null if not found.
func get_entity_by_id(id: StringName) -> Node:
	return _entities_by_id.get(id, null)

## Returns all entities with the specified tag.
## Filters out invalid instances.
func get_entities_by_tag(tag: StringName) -> Array[Node]:
	var results: Array[Node] = []
	if not _entities_by_tag.has(tag):
		return results

	var entities: Array = _entities_by_tag[tag]
	for entity_variant in entities:
		var entity := entity_variant as Node
		if entity == null:
			continue
		if not is_instance_valid(entity):
			continue
		results.append(entity)

	return results

## Returns all entities that have ANY of the specified tags (match_all=false)
## or ALL of the specified tags (match_all=true).
## Deduplicates results.
func get_entities_by_tags(tags: Array[StringName], match_all: bool = false) -> Array[Node]:
	var results: Array[Node] = []
	if tags.is_empty():
		return results

	if match_all:
		# Entity must have ALL tags
		var candidates: Dictionary = {}  # Node → tag count
		for tag in tags:
			var entities := get_entities_by_tag(tag)
			for entity in entities:
				candidates[entity] = candidates.get(entity, 0) + 1

		# Only include entities that have all tags
		for entity in candidates.keys():
			if candidates[entity] == tags.size():
				results.append(entity)
	else:
		# Entity must have ANY tag
		var seen: Dictionary = {}
		for tag in tags:
			var entities := get_entities_by_tag(tag)
			for entity in entities:
				if not seen.has(entity):
					results.append(entity)
					seen[entity] = true

	return results

## Returns all registered entity IDs.
func get_all_entity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _entities_by_id.keys():
		ids.append(StringName(key))
	return ids

## Updates the tag index for an entity when its tags change.
## Called by entities when they add/remove tags.
func update_entity_tags(entity: Node) -> void:
	if entity == null:
		return
	if not _registered_entities.has(entity):
		return

	_unindex_entity_tags(entity)
	_index_entity_tags(entity)

## Gets the entity ID from an entity node.
## Calls entity.get_entity_id() if available, otherwise generates from name.
func _get_entity_id(entity: Node) -> StringName:
	if entity == null:
		return StringName("")
	var typed_entity := entity as I_ECSEntity
	if typed_entity != null:
		return typed_entity.get_entity_id()

	# Fallback: generate ID from node name
	var node_name := String(entity.name)
	if node_name.begins_with("E_"):
		node_name = node_name.substr(2)
	return StringName(node_name.to_lower())

## Indexes an entity's tags in the tag lookup dictionary.
func _index_entity_tags(entity: Node) -> void:
	if entity == null:
		return

	var tags := _get_entity_tags(entity)
	for tag in tags:
		if not _entities_by_tag.has(tag):
			_entities_by_tag[tag] = []
		var tag_array: Array = _entities_by_tag[tag]
		if not tag_array.has(entity):
			tag_array.append(entity)

## Removes an entity from all tag indexes.
func _unindex_entity_tags(entity: Node) -> void:
	if entity == null:
		return

	# Remove entity from ALL tags that currently contain it
	# (don't rely on entity.get_tags() since tags may have changed)
	for tag in _entities_by_tag.keys():
		var tag_array: Array = _entities_by_tag[tag]
		if tag_array.has(entity):
			tag_array.erase(entity)
			if tag_array.is_empty():
				_entities_by_tag.erase(tag)

## Gets the tags from an entity node.
## Calls entity.get_tags() if available, otherwise returns empty array.
func _get_entity_tags(entity: Node) -> Array[StringName]:
	if entity == null:
		return []
	var typed_entity := entity as I_ECSEntity
	if typed_entity != null:
		return typed_entity.get_tags()
	return []

## Checks if an entity has a specific tag.
func _entity_has_tag(entity: Node, tag: StringName) -> bool:
	if entity == null:
		return false
	var typed_entity := entity as I_ECSEntity
	if typed_entity != null:
		return typed_entity.has_tag(tag)
	return _get_entity_tags(entity).has(tag)

func _track_component(component: BaseECSComponent, type_name: StringName) -> void:
	var entity := _get_entity_for_component(component)
	if entity == null:
		return

	# Auto-register entity when first component is added
	if not _registered_entities.has(entity):
		register_entity(entity)

	_node_entity_cache[component.get_instance_id()] = entity

	if not _entity_component_map.has(entity):
		_entity_component_map[entity] = {}
		_ensure_entity_exit_tracking(entity)

	var tracked_components: Dictionary = _entity_component_map[entity]
	tracked_components[type_name] = component
	_entity_component_map[entity] = tracked_components
	_invalidate_query_cache()

func _untrack_component(component: BaseECSComponent, type_name: StringName) -> void:
	var entity: Node = _node_entity_cache.get(component.get_instance_id(), null) as Node
	_node_entity_cache.erase(component.get_instance_id())

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

func _ensure_entity_exit_tracking(entity: Node) -> void:
	if entity == null:
		return
	if _tracked_entities.has(entity):
		return
	_tracked_entities[entity] = true
	entity.connect("tree_exited", Callable(self, "_on_tracked_entity_exited").bind(entity), Object.CONNECT_ONE_SHOT)

func _get_entity_for_component(component: BaseECSComponent, warn_on_missing: bool = true) -> Node:
	if component == null:
		return null
	var entity := U_ECS_UTILS.find_entity_root(component)
	if entity != null:
		return entity
	if warn_on_missing:
		push_error("M_ECSManager: Component %s has no entity root ancestor" % component.name)
	return null

func _find_entity_for_component(component: BaseECSComponent) -> Node:
	for entity in _entity_component_map.keys():
		var tracked_components: Dictionary = _entity_component_map[entity]
		if tracked_components.values().has(component):
			return entity
	return null

func _on_tracked_entity_exited(entity: Node) -> void:
	var tracked_components: Dictionary = _entity_component_map.get(entity, {})
	for component_variant in tracked_components.values():
		var comp := component_variant as BaseECSComponent
		if comp != null:
			_node_entity_cache.erase(comp.get_instance_id())

	_entity_component_map.erase(entity)
	_node_entity_cache.erase(entity.get_instance_id())
	_tracked_entities.erase(entity)
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

func _get_current_time() -> float:
	if _time_provider != Callable() and _time_provider.is_valid():
		var value: Variant = _time_provider.call()
		return float(value)
	return U_ECS_UTILS.get_current_time()

func _invalidate_query_cache() -> void:
	if _query_cache.is_empty():
		return
	_query_cache.clear()

func mark_systems_dirty() -> void:
	_systems_dirty = true

func _ensure_systems_sorted() -> void:
	if not _systems_dirty:
		return
	_sort_systems()
	_systems_dirty = false

func _sort_systems() -> void:
	var valid_systems: Array[BaseECSSystem] = []
	for system in _systems:
		if system == null:
			continue
		if not is_instance_valid(system):
			continue
		valid_systems.append(system)
	_systems = valid_systems
	_sorted_systems = valid_systems.duplicate()
	_sorted_systems.sort_custom(Callable(self, "_compare_system_priority"))

func _compare_system_priority(a: BaseECSSystem, b: BaseECSSystem) -> bool:
	var priority_a: int = a.execution_priority
	var priority_b: int = b.execution_priority
	if priority_a == priority_b:
		return a.get_instance_id() < b.get_instance_id()
	return priority_a < priority_b

func _physics_process(delta: float) -> void:
	_ensure_systems_sorted()
	if _sorted_systems.is_empty():
		return

	var needs_cleanup := false
	for system in _sorted_systems:
		if system == null:
			needs_cleanup = true
			continue
		if not is_instance_valid(system):
			needs_cleanup = true
			continue
		if system.is_debug_disabled():
			continue
		system.process_tick(delta)

	if needs_cleanup:
		mark_systems_dirty()
