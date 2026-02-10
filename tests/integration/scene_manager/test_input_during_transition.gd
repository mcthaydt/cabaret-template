extends GutTest

## Integration test: Pause actions during transitions
## T074: Updated from ESC input tests to navigation action tests


var _root: Node
var _store: M_StateStore
var _manager: M_SceneManager
var _ui: CanvasLayer
var _active: Node
var _transition_overlay: CanvasLayer

func before_each() -> void:
    U_ServiceLocator.clear()

    var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
    _root = root_ctx["root"]
    add_child_autofree(_root)
    _active = root_ctx["active_scene_container"]
    _ui = root_ctx["ui_overlay_stack"]
    _transition_overlay = root_ctx["transition_overlay"]

    _store = M_StateStore.new()
    _store.settings = RS_StateStoreSettings.new()
    _store.scene_initial_state = RS_SceneInitialState.new()
    _store.navigation_initial_state = RS_NavigationInitialState.new()
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

    _root = null
    _store = null
    _manager = null
    _ui = null
    _active = null
    _transition_overlay = null

func test_pause_action_does_not_interfere_with_transition() -> void:
    # T074: Updated to use navigation actions instead of direct ESC input
    # Test that pause actions during transitions don't disrupt scene loading

    # Start gameplay and begin a fade transition (slow enough to remain in progress)
    _store.dispatch(U_NavigationActions.start_game(StringName("main_menu")))
    _manager.transition_to_scene(StringName("main_menu"), "fade")
    await get_tree().physics_frame

    # Record overlay count before pause action
    var before_count := _ui.get_child_count()

    # Dispatch pause action during transition
    _store.dispatch(U_NavigationActions.open_pause())
    await get_tree().physics_frame

    # Overlay should not be pushed during transition (reconciliation defers)
    var after_count := _ui.get_child_count()
    assert_eq(after_count, before_count, "Pause overlay should not push during transition")

    # Wait for transition to complete
    await wait_physics_frames(15)

    # Verify transition completed successfully
    var scene_state: Dictionary = _store.get_slice(StringName("scene"))
    assert_false(scene_state.get("is_transitioning", false), "Transition should complete")
