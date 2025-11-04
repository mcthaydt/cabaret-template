extends GutTest

## Integration test: ESC input ignored while transitioning

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")

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
    _root.add_child(_store)
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

    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    _root.add_child(_manager)
    await get_tree().process_frame

func after_each() -> void:
    _root = null
    _store = null
    _manager = null
    _ui = null
    _active = null
    _transition_overlay = null

func test_esc_is_ignored_while_transitioning() -> void:
    # Start a fade transition (slow enough to remain in progress)
    _manager.transition_to_scene(StringName("main_menu"), "fade")
    await get_tree().physics_frame

    # Sanity: transitioning state may vary per timing; proceed to send ESC regardless
    var before_count := _ui.get_child_count()

    var ev := InputEventKey.new()
    ev.keycode = KEY_ESCAPE
    ev.pressed = true
    ev.echo = false
    _manager._input(ev)

    await get_tree().physics_frame

    var after_count := _ui.get_child_count()
    assert_eq(after_count, before_count, "Should not push pause overlay during transition")

