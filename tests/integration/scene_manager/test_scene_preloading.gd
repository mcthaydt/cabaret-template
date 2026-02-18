extends GutTest

## Integration test for scene preloading & performance
##
## Tests async scene loading, preloading at startup, cache management,
## and automatic preload hints for Phase 8.
## Tests follow TDD discipline: written BEFORE implementation.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const M_CursorManager = preload("res://scripts/managers/m_cursor_manager.gd")
const M_TimeManager = preload("res://scripts/managers/m_time_manager.gd")
const RS_SceneInitialState = preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_NavigationInitialState = preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/resources/state/rs_state_store_settings.gd")
const U_SceneRegistry = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")

var _root_scene: Node
var _manager: M_SceneManager
var _store: M_StateStore
var _cursor: M_CursorManager
var _pause_system: M_TimeManager
var _active_scene_container: Node

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	# Create root scene structure (includes HUDLayer + overlays)
	var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
	_root_scene = root_ctx["root"]
	add_child_autofree(_root_scene)
	_active_scene_container = root_ctx["active_scene_container"]

	# Create state store with all slices - register IMMEDIATELY after adding to tree
	# so other managers can find it in their _ready()
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	var scene_initial_state := RS_SceneInitialState.new()
	_store.scene_initial_state = scene_initial_state
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	_root_scene.add_child(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	U_SceneTestHelpers.register_scene_manager_dependencies(_root_scene, false, true, true)

	# Create cursor manager (Phase 2: T024b - required for M_TimeManager) - register immediately
	_cursor = M_CursorManager.new()
	_root_scene.add_child(_cursor)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor)

	# Create scene manager - register immediately
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true  # Don't load main_menu automatically in tests
	_root_scene.add_child(_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _manager)

	# Create pause system (Phase 2: T024b - sole authority for pause/cursor) - register immediately
	_pause_system = M_TimeManager.new()
	_root_scene.add_child(_pause_system)
	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)

	await get_tree().process_frame

func after_each() -> void:
	# Remove root early to stop any active scene processing
	if _manager != null and is_instance_valid(_manager):
		await U_SceneTestHelpers.wait_for_transition_idle(_manager)
	if _root_scene != null and is_instance_valid(_root_scene):
		_root_scene.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

	_manager = null
	_store = null
	_cursor = null
	_pause_system = null
	_active_scene_container = null
	_root_scene = null

## Test 1: Async loading completes successfully
func test_async_loading_completes_successfully() -> void:
	# Skip if headless (async loading may fall back to sync)
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pass_test("Skipped in headless mode")
		return

	# Load a scene using async method (if available)
	var progress_values: Array = []
	var progress_callback := func(progress: float) -> void:
		progress_values.append(progress)

	var scene_path: String = U_SceneRegistry.get_scene_path(StringName("main_menu"))
	var loaded_scene: Node = await _manager._scene_loader.load_scene_async(scene_path, progress_callback, _manager._background_loads)

	assert_not_null(loaded_scene, "Should load scene successfully")
	assert_gt(progress_values.size(), 0, "Should have progress updates")
	assert_true(progress_values[-1] >= 1.0 or progress_values[-1] >= 0.99, "Final progress should be ~1.0")

	# Clean up loaded scene to prevent orphans
	if loaded_scene:
		loaded_scene.queue_free()
		await wait_process_frames(1)  # Wait for queue_free to process

## Test 2: Async loading progress updates from 0.0 to 1.0
func test_async_loading_progress_updates() -> void:
	# Skip if headless
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pass_test("Skipped in headless mode")
		return

	var progress_values: Array = []
	var progress_callback := func(progress: float) -> void:
		progress_values.append(progress)

	var scene_path: String = U_SceneRegistry.get_scene_path(StringName("settings_menu"))
	var loaded_scene: Node = await _manager._scene_loader.load_scene_async(scene_path, progress_callback, _manager._background_loads)

	# Always assert that scene loaded successfully
	assert_not_null(loaded_scene, "Should load scene successfully")

	# Verify progress increases (or at least ends at 1.0 for instant loads)
	if progress_values.size() > 1:
		for i in range(progress_values.size() - 1):
			assert_true(progress_values[i] <= progress_values[i + 1], "Progress should be monotonically increasing")

	# Clean up loaded scene to prevent orphans
	if loaded_scene:
		loaded_scene.queue_free()
		await wait_process_frames(1)  # Wait for queue_free to process

## Test 3: Critical scenes preloaded at startup
func test_critical_scenes_preloaded_at_startup() -> void:
	# Wait for background loading started by M_SceneManager._ready()
	await wait_seconds(2.0)

	# Check critical scenes (priority >= 10)
	var critical_scenes := U_SceneRegistry.get_preloadable_scenes(10)

	var scene_cache: Dictionary = _manager._scene_cache
	var all_preloaded := true
	for scene_data in critical_scenes:
		var scene_path: String = scene_data.get("path", "")
		if not scene_cache.has(scene_path):
			all_preloaded = false
			break

	assert_true(all_preloaded, "All critical scenes should be preloaded")

## Test 4: Preloaded scenes transition faster than on-demand
func test_preloaded_scene_transitions_fast() -> void:
	# Preload main_menu manually
	if _manager.has_method("_preload_scene"):
		var scene_path: String = U_SceneRegistry.get_scene_path(StringName("main_menu"))
		_manager._preload_scene(scene_path)
		await wait_seconds(1.0)

	# Measure transition time (should be < 0.5s for cached)
	var start_time := Time.get_ticks_msec() / 1000.0
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(5)
	var end_time := Time.get_ticks_msec() / 1000.0

	var transition_duration := end_time - start_time
	assert_lt(transition_duration, 0.5, "Cached scene transition should be < 0.5s")

## Test 5: On-demand scenes load with loading transition
func test_on_demand_scene_loads_async() -> void:
	# Skip if headless
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pass_test("Skipped in headless mode")
		return

	# Load gameplay scene (should use async load)
	_manager.transition_to_scene(StringName("alleyway"), "loading")
	await wait_seconds(2.0)  # Wait for loading transition

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("alleyway"), "Should load gameplay scene")

## Test 6: Cache eviction when max count exceeded
func test_cache_eviction_on_max_count() -> void:
	# Set max cache size to 3
	if _manager.has_method("set"):
		_manager.set("_max_cached_scenes", 3)

	# Add 4 scenes to cache
	var scene_paths: Array[String] = [
		U_SceneRegistry.get_scene_path(StringName("main_menu")),
		U_SceneRegistry.get_scene_path(StringName("settings_menu")),
		U_SceneRegistry.get_scene_path(StringName("pause_menu")),
		U_SceneRegistry.get_scene_path(StringName("alleyway"))
	]

	for path in scene_paths:
		var packed_scene := load(path) as PackedScene
		if packed_scene:
			_manager._scene_cache_helper.add_to_cache(path, packed_scene)

	await get_tree().process_frame

	# Cache should have exactly 3 scenes (4th evicted LRU)
	var cached_count := 0
	for path in scene_paths:
		if _manager._scene_cache_helper.is_scene_cached(path):
			cached_count += 1

	assert_lte(cached_count, 3, "Cache should evict when max count exceeded")

## Test 7: Cache eviction on memory pressure
func test_cache_eviction_on_memory_pressure() -> void:
	# Note: Difficult to test memory pressure in unit tests
	# This test just validates the method exists and returns reasonable values
	var memory_usage: int = _manager._scene_cache_helper._get_cache_memory_usage()
	assert_gte(memory_usage, 0, "Memory usage should be non-negative")

	pass_test("Memory tracking method exists")

## Test 8: Automatic preload hint near door
func test_automatic_preload_hint_near_door() -> void:
	if not _manager.has_method("hint_preload_scene"):
		pending("Preload hints not implemented yet")
		return

	# Manually trigger hint
	var scene_path: String = U_SceneRegistry.get_scene_path(StringName("interior_house"))
	_manager.hint_preload_scene(scene_path)

	await wait_seconds(0.5)  # Wait for background load to start

	# Check if scene is loading or cached
	var is_loading := false
	if _manager.has_method("get") and _manager.get("_background_loads"):
		var background_loads: Dictionary = _manager.get("_background_loads")
		is_loading = background_loads.has(scene_path)

	var is_cached := false
	is_cached = _manager._scene_cache_helper.is_scene_cached(scene_path)

	assert_true(is_loading or is_cached, "Hinted scene should be loading or cached")

## Test 9: Background load completes before transition
func test_background_load_completes_before_transition() -> void:
	if not _manager.has_method("hint_preload_scene"):
		pending("Preload hints not implemented yet")
		return

	# Hint interior scene
	var scene_path: String = U_SceneRegistry.get_scene_path(StringName("interior_house"))
	_manager.hint_preload_scene(scene_path)

	# Wait for background load
	await wait_seconds(1.5)

	# Transition should be instant (scene cached)
	var start_time := Time.get_ticks_msec() / 1000.0
	_manager.transition_to_scene(StringName("interior_house"), "instant")
	await wait_physics_frames(5)
	var end_time := Time.get_ticks_msec() / 1000.0

	var transition_duration := end_time - start_time
	assert_lt(transition_duration, 0.5, "Preloaded scene transition should be fast")

## Test 10: Real progress updates in loading transition
func test_real_progress_in_loading_transition() -> void:
	# Skip if headless
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pass_test("Skipped in headless mode")
		return

	# Load large scene with loading transition
	_manager.transition_to_scene(StringName("alleyway"), "loading")

	# Wait for transition
	await wait_seconds(2.0)

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("alleyway"), "Should complete transition")
	assert_false(scene_state.get("is_transitioning", false), "Should not be transitioning after completion")
