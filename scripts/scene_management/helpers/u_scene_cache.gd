extends RefCounted
class_name U_SceneCache

## Scene cache and background preload helper
##
## Extracted from M_SceneManager (Phase 9A - T090a).
## Responsible for:
## - Tracking PackedScene cache entries
## - Estimating cache memory usage
## - Managing background threaded preloads and hint preloads

## Cache: path → PackedScene
var _scene_cache: Dictionary = {}

## Background loading tracking
## Key: path (String), Value: { scene_id, status, start_time }
var _background_loads: Dictionary = {}

## LRU tracking
## Key: path (String), Value: timestamp (float)
var _cache_access_times: Dictionary = {}

## Cache limits
var _max_cached_scenes: int = 5
var _max_cache_memory: int = 100 * 1024 * 1024  # 100MB

## Background polling active flag
var _is_background_polling_active: bool = false

## Check if scene is cached
func is_scene_cached(scene_path: String) -> bool:
	return _scene_cache.has(scene_path)

## Get cached PackedScene (updates LRU access time)
func get_cached_scene(scene_path: String) -> PackedScene:
	if not _scene_cache.has(scene_path):
		return null

	# Update LRU access time
	_cache_access_times[scene_path] = Time.get_ticks_msec() / 1000.0

	return _scene_cache[scene_path] as PackedScene

## Add PackedScene to cache (with eviction if needed)
func add_to_cache(scene_path: String, packed_scene: PackedScene) -> void:
	if packed_scene == null:
		return

	_scene_cache[scene_path] = packed_scene
	_cache_access_times[scene_path] = Time.get_ticks_msec() / 1000.0

	_check_cache_pressure()

## Preload critical scenes at startup.
##
## Expects an Array of Dictionaries with:
## - "scene_id": StringName
## - "path": String
func preload_critical_scenes(critical_scenes: Array) -> void:
	if critical_scenes.is_empty():
		return

	for scene_data in critical_scenes:
		var scene_id: StringName = scene_data.get("scene_id", StringName(""))
		var scene_path: String = scene_data.get("path", "")

		if scene_path.is_empty():
			push_warning("U_SceneCache: Critical scene '%s' has empty path" % scene_id)
			continue

		if is_scene_cached(scene_path):
			continue

		var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
		if err != OK:
			push_error("U_SceneCache: Failed to start preload for '%s' (error %d)" % [scene_id, err])
			continue

		_background_loads[scene_path] = {
			"scene_id": scene_id,
			"status": ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			"start_time": Time.get_ticks_msec() / 1000.0
		}

	if not _background_loads.is_empty() and not _is_background_polling_active:
		_is_background_polling_active = true
		_start_background_load_polling()

## Hint to preload a scene in background.
##
## Called when player approaches a door trigger to preload target scene.
## Non-blocking - loads in background while player is in trigger zone.
func hint_preload_scene(scene_path: String) -> void:
	if is_scene_cached(scene_path):
		return

	if _background_loads.has(scene_path):
		return

	var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		push_error("U_SceneCache: Failed to start hinted preload for '%s' (error %d)" % [scene_path, err])
		return

	_background_loads[scene_path] = {
		"scene_id": scene_path.get_file().get_basename(),
		"status": ResourceLoader.THREAD_LOAD_IN_PROGRESS,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

	if not _is_background_polling_active:
		_is_background_polling_active = true
		_start_background_load_polling()

## Internal: background polling loop for preloaded scenes
func _start_background_load_polling() -> void:
	while not _background_loads.is_empty():
		var completed_paths: Array = []

		for scene_path in _background_loads:
			var load_data: Dictionary = _background_loads[scene_path]
			var status: int = ResourceLoader.load_threaded_get_status(scene_path)

			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
				if packed_scene:
					add_to_cache(scene_path, packed_scene)
				else:
					push_error("U_SceneCache: Failed to get preloaded scene '%s'" % load_data.get("scene_id"))
				completed_paths.append(scene_path)
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				push_error("U_SceneCache: Preload failed for '%s'" % load_data.get("scene_id"))
				completed_paths.append(scene_path)
			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("U_SceneCache: Invalid resource for preload '%s'" % load_data.get("scene_id"))
				completed_paths.append(scene_path)

		for path in completed_paths:
			_background_loads.erase(path)

		if not _background_loads.is_empty():
			var main_loop := Engine.get_main_loop()
			if main_loop is SceneTree:
				await (main_loop as SceneTree).process_frame

	_is_background_polling_active = false

## Check cache pressure and evict if necessary (hybrid policy)
func _check_cache_pressure() -> void:
	while _scene_cache.size() > _max_cached_scenes:
		_evict_cache_lru()

	var memory_usage: int = _get_cache_memory_usage()
	while memory_usage > _max_cache_memory and _scene_cache.size() > 0:
		_evict_cache_lru()
		memory_usage = _get_cache_memory_usage()

## Evict least-recently-used scene from cache
func _evict_cache_lru() -> void:
	if _scene_cache.is_empty():
		return

	var lru_path: String = ""
	var lru_time: float = INF

	for path in _cache_access_times:
		var access_time: float = _cache_access_times[path]
		if access_time < lru_time:
			lru_time = access_time
			lru_path = path

	if not lru_path.is_empty():
		_scene_cache.erase(lru_path)
		_cache_access_times.erase(lru_path)

## Get estimated cache memory usage in bytes
func _get_cache_memory_usage() -> int:
	var total_bytes: int = 0

	for scene_path in _scene_cache:
		if "gameplay" in scene_path:
			total_bytes += 7 * 1024 * 1024
		else:
			total_bytes += 1 * 1024 * 1024

	return total_bytes

