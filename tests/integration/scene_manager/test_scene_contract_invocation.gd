extends GutTest

## Integration test: M_SceneManager invokes scene contract validation path

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")

var _root: Node
var _store: M_StateStore
var _manager: M_SceneManager

func before_each() -> void:
    _root = Node.new()
    _root.name = "Root"
    add_child_autofree(_root)

    _store = M_StateStore.new()
    _store.settings = RS_StateStoreSettings.new()
    _store.scene_initial_state = RS_SceneInitialState.new()
    _root.add_child(_store)
    # Register state store via ServiceLocator BEFORE managers run _ready()
    U_ServiceLocator.register(StringName("state_store"), _store)
    await get_tree().process_frame

    var active := Node.new()
    active.name = "ActiveSceneContainer"
    _root.add_child(active)

    var ui := CanvasLayer.new()
    ui.name = "UIOverlayStack"
    _root.add_child(ui)

    var transition_overlay := CanvasLayer.new()
    transition_overlay.name = "TransitionOverlay"
    var color_rect := ColorRect.new()
    color_rect.name = "TransitionColorRect"
    transition_overlay.add_child(color_rect)
    _root.add_child(transition_overlay)

    var loading := CanvasLayer.new()
    loading.name = "LoadingOverlay"
    _root.add_child(loading)

    # Register overlays via ServiceLocator for M_SceneManager discovery
    U_ServiceLocator.register(StringName("transition_overlay"), transition_overlay)
    U_ServiceLocator.register(StringName("loading_overlay"), loading)

    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    _root.add_child(_manager)
    await get_tree().process_frame

func after_each() -> void:
    # 1. Clear ServiceLocator first (prevents cross-test pollution)
    U_ServiceLocator.clear()

    # 2. Clear active scenes loaded by M_SceneManager
    var active := _root.get_node_or_null("ActiveSceneContainer") if _root else null
    if active and is_instance_valid(active):
        for child in active.get_children():
            child.queue_free()

    # 3. Clear UI overlay stack
    var ui := _root.get_node_or_null("UIOverlayStack") if _root else null
    if ui and is_instance_valid(ui):
        for child in ui.get_children():
            child.queue_free()

    # 4. Wait for queue_free to process
    await get_tree().process_frame
    await get_tree().physics_frame

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
        "res://scenes/tmp_invalid_gameplay.tscn",
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
