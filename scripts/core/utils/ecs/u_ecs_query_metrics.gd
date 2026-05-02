extends RefCounted

## ECS query metrics helper
##
## Extracted from M_ECSManager (Phase 9E - T094a/T094b).
## Responsible for:
## - Tracking per-query metrics (calls, cache hits, durations)
## - Enforcing a bounded metrics capacity with LRU-style eviction
## - Providing a normalized metrics snapshot for debug UIs

var _query_metrics: Dictionary = {}
var _query_metrics_enabled: bool = true
var _query_metrics_capacity: int = 64

func get_query_metrics_enabled() -> bool:
	return _query_metrics_enabled

func set_query_metrics_enabled(enabled: bool) -> void:
	if _query_metrics_enabled == enabled:
		return
	_query_metrics_enabled = enabled
	if not _query_metrics_enabled:
		clear_query_metrics()

func get_query_metrics_capacity() -> int:
	return _query_metrics_capacity

func set_query_metrics_capacity(capacity: int) -> void:
	var clamped: int = max(capacity, 0)
	if _query_metrics_capacity == clamped:
		return
	_query_metrics_capacity = clamped
	_enforce_query_metric_capacity()

func get_query_metrics() -> Array:
	if not _query_metrics_enabled:
		return []

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

func clear_query_metrics() -> void:
	if _query_metrics.is_empty():
		return
	_query_metrics.clear()

func record_query_metrics(
	key: String,
	required: Array[StringName],
	optional: Array[StringName],
	result_count: int,
	duration: float,
	was_cache_hit: bool,
	timestamp: float
) -> void:
	if not _query_metrics_enabled:
		return

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
	_enforce_query_metric_capacity()

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

func _enforce_query_metric_capacity() -> void:
	if _query_metrics_capacity <= 0:
		return
	if _query_metrics.size() <= _query_metrics_capacity:
		return

	var keys: Array[String] = []
	for raw_key in _query_metrics.keys():
		keys.append(String(raw_key))
	keys.sort_custom(Callable(self, "_compare_metric_keys_by_recency"))

	for index in range(_query_metrics_capacity, keys.size()):
		var key: String = keys[index]
		if _query_metrics.has(key):
			_query_metrics.erase(key)

func _compare_metric_keys_by_recency(a: String, b: String) -> bool:
	var data_a: Dictionary = _query_metrics.get(a, {})
	var data_b: Dictionary = _query_metrics.get(b, {})
	var time_a: float = float(data_a.get("last_run_time", 0.0))
	var time_b: float = float(data_b.get("last_run_time", 0.0))
	if is_equal_approx(time_a, time_b):
		return String(a) < String(b)
	return time_a > time_b
