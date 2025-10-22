extends RefCounted

class_name U_ECSDebugDataSource

const EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")

static func build_snapshot(manager: M_ECSManager) -> Dictionary:
	return {
		"queries": get_query_metrics(manager),
		"events": get_event_history(),
		"systems": get_system_overview(manager),
	}

static func get_query_metrics(manager: M_ECSManager) -> Array:
	var formatted: Array = []
	if manager == null:
		return formatted

	var metrics: Array = manager.get_query_metrics()
	for entry in metrics:
		var required: Array = _duplicate_string_names(entry.get("required", []))
		var optional: Array = _duplicate_string_names(entry.get("optional", []))
		var total_calls: int = int(entry.get("total_calls", 0))
		var cache_hits: int = int(entry.get("cache_hits", 0))
		var cache_hit_rate: float = 0.0
		if total_calls > 0:
			cache_hit_rate = float(cache_hits) / float(total_calls)

		formatted.append({
			"id": String(entry.get("id", "")),
			"required": required,
			"optional": optional,
			"total_calls": total_calls,
			"cache_hits": cache_hits,
			"cache_hit_rate": cache_hit_rate,
			"last_duration": float(entry.get("last_duration", 0.0)),
			"last_result_count": int(entry.get("last_result_count", 0)),
			"last_run_time": float(entry.get("last_run_time", 0.0)),
		})

	return formatted

static func get_system_overview(manager: M_ECSManager) -> Array:
	var overview: Array = []
	if manager == null:
		return overview

	var systems: Array = manager.get_systems()
	for system in systems:
		if system == null:
			continue
		if not is_instance_valid(system):
			continue

		var script_path := ""
		var script_resource: Script = system.get_script() as Script
		if script_resource != null:
			script_path = script_resource.resource_path

		overview.append({
			"name": system.name,
			"class": system.get_class(),
			"script": script_path,
			"priority": system.execution_priority,
			"enabled": not system.is_debug_disabled(),
			"instance_id": system.get_instance_id(),
		})

	return overview

static func get_event_history() -> Array:
	var history: Array = EVENT_BUS.get_event_history()
	return history.duplicate(true)

static func serialize_event_history(events: Array) -> String:
	var safe_events: Array = []
	for event in events:
		safe_events.append(_convert_to_json_safe(event))
	return JSON.stringify(safe_events)

static func _duplicate_string_names(source: Variant) -> Array:
	var result: Array[StringName] = []
	if source is Array:
		for entry in source:
			result.append(StringName(entry))
	elif source is PackedStringArray:
		for entry in source:
			result.append(StringName(entry))
	return result

static func _convert_to_json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var copy: Dictionary = {}
		for key in value.keys():
			var safe_key := _convert_variant_to_string(key)
			copy[safe_key] = _convert_to_json_safe(value[key])
		return copy
	if value is Array:
		var array_copy: Array = []
		for entry in value:
			array_copy.append(_convert_to_json_safe(entry))
		return array_copy
	if value is StringName:
		return String(value)
	return value

static func _convert_variant_to_string(value: Variant) -> String:
	if value is StringName:
		return String(value)
	if value is String:
		return value
	return String(value)
