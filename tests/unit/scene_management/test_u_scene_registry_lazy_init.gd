extends GutTest

## Regression tests for U_SceneRegistry lazy initialization.
##
## Covers the fix for the timing bug where _static_init fired before
## root._enter_tree() could register extension loaders, causing scenes
## like demo_room to be missing from the registry at save-load time.

var _scenes_backup: Dictionary
var _loaded_flag_backup: bool
var _extension_loaders_backup: Array[Callable]
var _pending_entries_backup: Array[Resource]


func before_each() -> void:
	_scenes_backup = (U_SceneRegistry._scenes as Dictionary).duplicate(true)
	_loaded_flag_backup = U_SceneRegistry._resource_entries_loaded
	_extension_loaders_backup = U_SceneRegistryLoader._extension_loaders.duplicate()
	_pending_entries_backup = U_SceneRegistryLoader._pending_extra_entries.duplicate()


func after_each() -> void:
	U_SceneRegistry._scenes = _scenes_backup
	U_SceneRegistry._resource_entries_loaded = _loaded_flag_backup
	U_SceneRegistryLoader._extension_loaders = _extension_loaders_backup
	U_SceneRegistryLoader._pending_extra_entries = _pending_entries_backup


func _reset_lazy_state() -> void:
	U_SceneRegistry._scenes = {}
	U_SceneRegistry._resource_entries_loaded = false
	U_SceneRegistryLoader._extension_loaders = []
	U_SceneRegistryLoader._pending_extra_entries = []


# --- Flag behaviour ---

func test_flag_is_false_before_any_access() -> void:
	_reset_lazy_state()
	assert_false(U_SceneRegistry._resource_entries_loaded,
		"_resource_entries_loaded must be false until an accessor is called")


func test_ensure_loaded_sets_flag() -> void:
	_reset_lazy_state()
	U_SceneRegistry._ensure_loaded()
	assert_true(U_SceneRegistry._resource_entries_loaded,
		"_ensure_loaded() must set _resource_entries_loaded to true")


func test_ensure_loaded_does_not_reload_once_set() -> void:
	_reset_lazy_state()
	U_SceneRegistry._ensure_loaded()
	# Register a loader after first load — it must NOT run on a second _ensure_loaded call.
	var call_markers: Array[bool] = [false]
	U_SceneRegistryLoader.add_extension_loader(func() -> void: call_markers[0] = true)
	U_SceneRegistry._ensure_loaded()
	assert_false(call_markers[0],
		"_ensure_loaded() must be a no-op after the first call")


# --- Accessor coverage ---

func test_get_scene_triggers_lazy_load() -> void:
	_reset_lazy_state()
	U_SceneRegistry.get_scene(&"main_menu")
	assert_true(U_SceneRegistry._resource_entries_loaded,
		"get_scene() must trigger lazy load")


func test_get_all_scenes_triggers_lazy_load() -> void:
	_reset_lazy_state()
	U_SceneRegistry.get_all_scenes()
	assert_true(U_SceneRegistry._resource_entries_loaded,
		"get_all_scenes() must trigger lazy load")


func test_get_scenes_by_type_triggers_lazy_load() -> void:
	_reset_lazy_state()
	U_SceneRegistry.get_scenes_by_type(0)
	assert_true(U_SceneRegistry._resource_entries_loaded,
		"get_scenes_by_type() must trigger lazy load")


func test_get_preloadable_scenes_triggers_lazy_load() -> void:
	_reset_lazy_state()
	U_SceneRegistry.get_preloadable_scenes()
	assert_true(U_SceneRegistry._resource_entries_loaded,
		"get_preloadable_scenes() must trigger lazy load")


func test_validate_door_pairings_triggers_lazy_load() -> void:
	_reset_lazy_state()
	U_SceneRegistry.validate_door_pairings()
	assert_true(U_SceneRegistry._resource_entries_loaded,
		"validate_door_pairings() must trigger lazy load")


# --- Core regression: extension loaders and load ordering ---

func test_extension_loader_registered_before_first_access_is_called() -> void:
	_reset_lazy_state()
	var call_markers: Array[bool] = [false]
	U_SceneRegistryLoader.add_extension_loader(func() -> void: call_markers[0] = true)
	U_SceneRegistry.get_scene(&"main_menu")
	assert_true(call_markers[0],
		"Extension loader registered before first access must run during lazy load")


func test_extension_loader_registered_after_first_access_is_not_called() -> void:
	_reset_lazy_state()
	U_SceneRegistry._ensure_loaded()
	var call_markers: Array[bool] = [false]
	U_SceneRegistryLoader.add_extension_loader(func() -> void: call_markers[0] = true)
	U_SceneRegistry.get_scene(&"main_menu")
	assert_false(call_markers[0],
		"Extension loader registered after first access must not run on subsequent gets")


func test_hardcoded_scenes_available_before_lazy_load() -> void:
	# Critical scenes registered in _register_scenes() must exist even if
	# _ensure_loaded() has never been called (they live in _scenes from _static_init).
	_reset_lazy_state()
	# Manually re-register only the hardcoded scenes (mirrors _static_init sans resource load).
	U_SceneRegistry._register_scenes()
	assert_true(U_SceneRegistry._scenes.has(&"main_menu"),
		"Hardcoded scenes must be available without triggering lazy load")
	assert_false(U_SceneRegistry._resource_entries_loaded,
		"Registering hardcoded scenes must not set the lazy-load flag")
