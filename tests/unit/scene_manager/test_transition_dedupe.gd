extends GutTest

## Unit tests for transition queue dedupe behavior

const U_SCENE_TRANSITION_QUEUE := preload("res://scripts/core/scene_management/helpers/u_scene_transition_queue.gd")

var _manager: M_SceneManager
var _store: M_StateStore
var _active: Node
var _hud_layer: CanvasLayer
var _ui: CanvasLayer
var _transition_overlay: CanvasLayer

func before_each() -> void:
    _store = M_StateStore.new()
    _store.settings = RS_StateStoreSettings.new()
    _store.scene_initial_state = RS_SceneInitialState.new()
    add_child_autofree(_store)
    await get_tree().process_frame

    _active = Node.new()
    _active.name = "ActiveSceneContainer"
    add_child_autofree(_active)
    U_ServiceLocator.register(StringName("active_scene_container"), _active)

    _ui = CanvasLayer.new()
    _ui.name = "UIOverlayStack"
    add_child_autofree(_ui)
    U_ServiceLocator.register(StringName("ui_overlay_stack"), _ui)

    _hud_layer = CanvasLayer.new()
    _hud_layer.name = "HUDLayer"
    add_child_autofree(_hud_layer)
    U_ServiceLocator.register(StringName("hud_layer"), _hud_layer)

    _transition_overlay = CanvasLayer.new()
    _transition_overlay.name = "TransitionOverlay"
    var cr := ColorRect.new()
    cr.name = "TransitionColorRect"
    _transition_overlay.add_child(cr)
    add_child_autofree(_transition_overlay)
    U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)

    var loading_overlay := CanvasLayer.new()
    loading_overlay.name = "LoadingOverlay"
    add_child_autofree(loading_overlay)
    U_ServiceLocator.register(StringName("loading_overlay"), loading_overlay)

    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    add_child_autofree(_manager)
    await get_tree().process_frame

func after_each() -> void:
    _manager = null
    _store = null
    _active = null
    _hud_layer = null
    _ui = null
    _transition_overlay = null

func _enqueue(scene_id: StringName, ttype: String, priority: int) -> void:
    # Access the helper directly to enqueue
    var queue_helper = _manager.get("_transition_queue_helper")
    queue_helper.enqueue(scene_id, ttype, priority)

func _get_queue_helper():
    return _manager.get("_transition_queue_helper")

func test_duplicate_lower_priority_is_ignored() -> void:
    _enqueue(StringName("main_menu"), "instant", M_SceneManager.Priority.HIGH)
    _enqueue(StringName("main_menu"), "instant", M_SceneManager.Priority.NORMAL)

    # Only one request should exist, with HIGH priority
    var queue_helper = _get_queue_helper()
    assert_eq(queue_helper.size(), 1)
    var req = queue_helper.pop_front()
    assert_eq(req.scene_id, StringName("main_menu"))
    assert_eq(req.transition_type, "instant")
    assert_eq(req.priority, M_SceneManager.Priority.HIGH)

func test_duplicate_higher_priority_replaces_existing() -> void:
    _enqueue(StringName("settings_panel"), "fade", M_SceneManager.Priority.NORMAL)
    _enqueue(StringName("settings_panel"), "fade", M_SceneManager.Priority.CRITICAL)

    var queue_helper = _get_queue_helper()
    assert_eq(queue_helper.size(), 1)
    var req = queue_helper.pop_front()
    assert_eq(req.priority, M_SceneManager.Priority.CRITICAL)
