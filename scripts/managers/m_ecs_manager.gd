@icon("res://editor_icons/manager.svg")
extends Node
class_name M_ECSManager

signal component_added(component_type: StringName, component: ECSComponent)
signal component_removed(component_type: StringName, component: ECSComponent)

const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const META_ENTITY_ROOT := StringName("_ecs_entity_root")
const META_ENTITY_TRACKED := StringName("_ecs_tracked_entity")

var _components: Dictionary = {}
var _systems: Array[ECSSystem] = []
var _sorted_systems: Array[ECSSystem] = []
var _systems_dirty: bool = true
var _entity_component_map: Dictionary = {}
var _query_cache: Dictionary = {}
var _query_metrics: Dictionary = {}
var _time_provider: Callable = Callable(U_ECS_UTILS, "get_current_time")

func _ready() -> void:
	add_to_group("ecs_manager")
	set_physics_process(true)

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
	_ensure_systems_sorted()
	return _sorted_systems.duplicate()

func get_components_for_entity(entity: Node) -> Dictionary:
	if entity == null:
		return {}
	if not _entity_component_map.has(entity):
		return {}
	return (_entity_component_map[entity] as Dictionary).duplicate(true)

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
	var metrics: Array = []
	for entry in _query_metrics.values():
		var metric: Dictionary = {
			"id": entry.get("id", ""),
			"required": _duplicate_string_names(entry.get("required", [])),
			"optional": _duplicate_string_names(entry.get("optional", [])),
			"total_calls": int(entry.get("total_calls", 0)),
			"cache_hits": int(entry.get("cache_hits", 0)),
			"last_duration": float(entry.get("last_duration", 0.0)),
			"last_result_count": int(entry.get("last_result_count", 0)),
			"last_run_time": float(entry.get("last_run_time", 0.0)),
		}
		metrics.append(metric)
	if metrics.size() > 1:
		metrics.sort_custom(Callable(self, "_compare_query_metrics"))
	return metrics

func register_system(system: ECSSystem) -> void:
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
	var results: Array[EntityQuery] = []
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
		_record_query_metrics(key, required, optional, cached_results.size(), 0.0, true, start_time)
		return _duplicate_query_results(cached_results)

	var candidate_components := get_components(candidate_type)
	if candidate_components.is_empty():
		var no_result_time: float = _get_current_time()
		var no_result_duration: float = max(no_result_time - start_time, 0.0)
		_record_query_metrics(key, required, optional, 0, no_result_duration, false, no_result_time)
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
	var end_time: float = _get_current_time()
	var duration: float = max(end_time - start_time, 0.0)
	_record_query_metrics(key, required, optional, results.size(), duration, false, end_time)

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

func _record_query_metrics(
	key: String,
	required: Array[StringName],
	optional: Array[StringName],
	result_count: int,
	duration: float,
	was_cache_hit: bool,
	timestamp: float
) -> void:
	var metrics: Dictionary = _query_metrics.get(key, {
		"id": key,
		"required": [],
		"optional": [],
		"total_calls": 0,
		"cache_hits": 0,
		"last_duration": 0.0,
		"last_result_count": 0,
		"last_run_time": 0.0,
	}) as Dictionary

	var required_copy: Array[StringName] = _duplicate_string_names(required)
	required_copy.sort()
	var optional_copy: Array[StringName] = _duplicate_string_names(optional)
	optional_copy.sort()

	var total_calls: int = int(metrics.get("total_calls", 0)) + 1
	var cache_hits: int = int(metrics.get("cache_hits", 0))
	if was_cache_hit:
		cache_hits += 1

	metrics["id"] = key
	metrics["required"] = required_copy
	metrics["optional"] = optional_copy
	metrics["total_calls"] = total_calls
	metrics["cache_hits"] = cache_hits
	metrics["last_duration"] = max(duration, 0.0)
	metrics["last_result_count"] = result_count
	metrics["last_run_time"] = timestamp

	_query_metrics[key] = metrics

func _duplicate_string_names(source: Variant) -> Array:
	var result: Array[StringName] = []
	if source is Array:
		for entry in source:
			result.append(StringName(entry))
	elif source is PackedStringArray:
		for entry in source:
			result.append(StringName(entry))
	return result

func _compare_query_metrics(a: Dictionary, b: Dictionary) -> bool:
	var time_a: float = float(a.get("last_run_time", 0.0))
	var time_b: float = float(b.get("last_run_time", 0.0))
	if is_equal_approx(time_a, time_b):
		return String(a.get("id", "")) < String(b.get("id", ""))
	return time_a > time_b

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
	var valid_systems: Array[ECSSystem] = []
	for system in _systems:
		if system == null:
			continue
		if not is_instance_valid(system):
			continue
		valid_systems.append(system)
	_systems = valid_systems
	_sorted_systems = valid_systems.duplicate()
	_sorted_systems.sort_custom(Callable(self, "_compare_system_priority"))

func _compare_system_priority(a: ECSSystem, b: ECSSystem) -> bool:
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
