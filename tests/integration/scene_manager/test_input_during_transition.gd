extends GutTest

## Integration test: Pause actions during transitions
## T074: Updated from ESC input tests to navigation action tests

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

var _root: Node
var _store: M_StateStore
var _manager: M_SceneManager
var _ui: CanvasLayer
var _active: Node
var _transition_overlay: CanvasLayer

func before_each() -> void:
    _root = Node.new()
    _root.name = "Root"
    add_child_autofree(_root)

    _store = M_StateStore.new()
    _store.settings = RS_StateStoreSettings.new()
    _store.scene_initial_state = RS_SceneInitialState.new()
    _store.navigation_initial_state = RS_NavigationInitialState.new()
    _root.add_child(_store)
    # Register state store via ServiceLocator BEFORE managers run _ready()
    U_ServiceLocator.register(StringName("state_store"), _store)
    await get_tree().process_frame

    _active = Node.new()
    _active.name = "ActiveSceneContainer"
    _root.add_child(_active)

    _ui = CanvasLayer.new()
    _ui.name = "UIOverlayStack"
    _root.add_child(_ui)

    _transition_overlay = CanvasLayer.new()
    _transition_overlay.name = "TransitionOverlay"
    var cr := ColorRect.new()
    cr.name = "TransitionColorRect"
    _transition_overlay.add_child(cr)
    _root.add_child(_transition_overlay)

    # Register overlays via ServiceLocator for M_SceneManager discovery
    U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)

    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    _root.add_child(_manager)
    await get_tree().process_frame

func after_each() -> void:
    # 1. Clear ServiceLocator first (prevents cross-test pollution)
    U_ServiceLocator.clear()

    # 2. Clear active scenes loaded by M_SceneManager
    if _active and is_instance_valid(_active):
        for child in _active.get_children():
            child.queue_free()

    # 3. Clear UI overlay stack
    if _ui and is_instance_valid(_ui):
        for child in _ui.get_children():
            child.queue_free()

    # 4. Wait for queue_free to process
    await get_tree().process_frame
    await get_tree().physics_frame

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

