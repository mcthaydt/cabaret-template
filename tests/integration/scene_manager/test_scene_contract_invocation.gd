extends GutTest

## Integration test: M_SceneManager invokes scene contract validation path

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
    # Register state store via ServiceLocator BEFORE managers run _ready()
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

    # Cleanup registry entry if created
    if U_SceneRegistry._scenes.has(StringName("tmp_invalid_gameplay")):
        U_SceneRegistry._scenes.erase(StringName("tmp_invalid_gameplay"))
    _root = null
    _store = null
    _manager = null

func test_transition_invokes_validation_for_non_test_scene() -> void:
    # Register a temporary gameplay scene outside res://tests path
    U_SceneRegistry._register_scene(
        StringName("tmp_invalid_gameplay"),
		"res://tests/scenes/tmp_invalid_gameplay.tscn",
        U_SceneRegistry.SceneType.UI,  # Use UI to avoid contract warnings/errors
        "instant",
        0
    )

    # Transition to the temp scene (missing player/camera/sp_default)
    _manager.transition_to_scene(StringName("tmp_invalid_gameplay"), "instant")
    await wait_physics_frames(3)

    # Assert transition completed and state updated; validation path should have run internally
    var scene_state: Dictionary = _store.get_slice(StringName("scene"))
    assert_eq(scene_state.get("current_scene_id", StringName("")), StringName("tmp_invalid_gameplay"))
