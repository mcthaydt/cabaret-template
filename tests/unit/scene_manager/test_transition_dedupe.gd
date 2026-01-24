extends GutTest

## Unit tests for transition queue dedupe behavior

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const U_SCENE_TRANSITION_QUEUE := preload("res://scripts/scene_management/helpers/u_scene_transition_queue.gd")

var _manager: M_SceneManager
var _store: M_StateStore
var _active: Node
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

    _ui = CanvasLayer.new()
    _ui.name = "UIOverlayStack"
    add_child_autofree(_ui)

    _transition_overlay = CanvasLayer.new()
    _transition_overlay.name = "TransitionOverlay"
    var cr := ColorRect.new()
    cr.name = "TransitionColorRect"
    _transition_overlay.add_child(cr)
    add_child_autofree(_transition_overlay)

    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    add_child_autofree(_manager)
    await get_tree().process_frame

func after_each() -> void:
    _manager = null
    _store = null
    _active = null
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
    _enqueue(StringName("settings_menu"), "fade", M_SceneManager.Priority.NORMAL)
    _enqueue(StringName("settings_menu"), "fade", M_SceneManager.Priority.CRITICAL)

    var queue_helper = _get_queue_helper()
    assert_eq(queue_helper.size(), 1)
    var req = queue_helper.pop_front()
    assert_eq(req.priority, M_SceneManager.Priority.CRITICAL)

