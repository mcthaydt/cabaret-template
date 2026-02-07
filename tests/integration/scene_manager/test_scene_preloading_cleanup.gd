extends GutTest

## Integration test for background preload cleanup/cache

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_SceneTestHelpers := preload("res://tests/helpers/u_scene_test_helpers.gd")

var _root: Node
var _store: M_StateStore
var _manager: M_SceneManager

func before_each() -> void:
    U_ServiceLocator.clear()

    var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
    _root = root_ctx["root"]
    add_child_autofree(_root)

    _store = M_StateStore.new()
    _store.settings = RS_StateStoreSettings.new()
    _store.scene_initial_state = RS_SceneInitialState.new()
    _root.add_child(_store)
    U_ServiceLocator.register(StringName("state_store"), _store)
    await get_tree().process_frame

    U_SceneTestHelpers.register_scene_manager_dependencies(_root)

    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    _root.add_child(_manager)
    U_ServiceLocator.register(StringName("scene_manager"), _manager)
    await get_tree().process_frame

func after_each() -> void:
    if _manager != null and is_instance_valid(_manager):
        await U_SceneTestHelpers.wait_for_transition_idle(_manager)
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
        await get_tree().process_frame
        await get_tree().physics_frame

    U_ServiceLocator.clear()

    _root = null
    _store = null
    _manager = null

func test_background_preload_completes_and_caches_scene() -> void:
    if not _manager.has_method("hint_preload_scene"):
        pending("Preload hints not implemented")
        return

    var scene_path := U_SceneRegistry.get_scene_path(StringName("interior_house"))
    if scene_path == "":
        pending("interior_house not registered")
        return

    _manager.hint_preload_scene(scene_path)

    # Wait for polling to complete
    await wait_seconds(1.5)

    # Background loads should be empty or not contain this path
    if _manager.has_method("get"):
        var loads: Dictionary = _manager.get("_background_loads")
        assert_true(not loads.has(scene_path) or loads.is_empty(), "Background load should be completed")

    # Scene should be cached
    assert_true(_manager._scene_cache_helper.is_scene_cached(scene_path), "Scene should be cached after background preload")
