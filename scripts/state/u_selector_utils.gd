@icon("res://resources/editor_icons/utility.svg")
extends RefCounted
class_name U_SelectorUtils

class MemoizedSelector extends RefCounted:
	var _selector_func: Callable
	var _last_version: int = -1
	var _cached_result: Variant = null
	var _dependencies: Array[String] = []
	var _last_signature: Array = []
	var _has_cached: bool = false
	var _cache_hits: int = 0
	var _cache_misses: int = 0
	var _dependency_hits: int = 0
	var _dependency_misses: int = 0

	func _init(selector_func: Callable) -> void:
		_selector_func = selector_func

	func with_dependencies(dependencies: Array) -> MemoizedSelector:
		_dependencies.clear()
		for dependency in dependencies:
			_dependencies.append(String(dependency))
		return self

	func get_metrics() -> Dictionary:
		return {
			"cache_hits": _cache_hits,
			"cache_misses": _cache_misses,
			"dependency_hits": _dependency_hits,
			"dependency_misses": _dependency_misses,
		}

	func reset_metrics() -> void:
		_cache_hits = 0
		_cache_misses = 0
		_dependency_hits = 0
		_dependency_misses = 0

	func select(state: Dictionary, state_version: int, resolver: Callable) -> Variant:
		if _dependencies.size() > 0:
			var signature: Array = []
			for path in _dependencies:
				signature.append(resolver.call(path))
			if !_has_cached or signature != _last_signature:
				_cached_result = _selector_func.call(state)
				_last_signature = signature.duplicate()
				_has_cached = true
				_cache_misses += 1
				_dependency_misses += 1
			else:
				_cache_hits += 1
				_dependency_hits += 1
			return _cached_result

		if !_has_cached or state_version != _last_version:
			_cached_result = _selector_func.call(state)
			_last_version = state_version
			_has_cached = true
			_cache_misses += 1
		else:
			_cache_hits += 1
		return _cached_result
