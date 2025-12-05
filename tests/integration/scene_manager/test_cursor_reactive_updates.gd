extends GutTest

## Integration test for reactive cursor updates on scene changes

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_CursorManager := preload("res://scripts/managers/m_cursor_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_PauseManager := preload("res://scripts/managers/m_pause_manager.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")

var _root: Node
var _store: M_StateStore
var _cursor: M_CursorManager
var _pause_system: M_PauseManager
var _manager: M_SceneManager

func before_each() -> void:
    _root = Node.new()
    _root.name = "Root"
    add_child_autofree(_root)

    # State store with all slices so subscriptions work in tests
    _store = M_StateStore.new()
    _store.settings = RS_StateStoreSettings.new()
    _store.boot_initial_state = RS_BootInitialState.new()
    _store.menu_initial_state = RS_MenuInitialState.new()
    _store.navigation_initial_state = RS_NavigationInitialState.new()
    _store.gameplay_initial_state = RS_GameplayInitialState.new()
    _store.scene_initial_state = RS_SceneInitialState.new()
    _root.add_child(_store)
    await get_tree().process_frame

    # Required containers/nodes for manager
    var active_container := Node.new()
    active_container.name = "ActiveSceneContainer"
    _root.add_child(active_container)

    var overlay := CanvasLayer.new()
    overlay.name = "UIOverlayStack"
    _root.add_child(overlay)

    var transition_overlay := CanvasLayer.new()
    transition_overlay.name = "TransitionOverlay"
    var color_rect := ColorRect.new()
    color_rect.name = "TransitionColorRect"
    transition_overlay.add_child(color_rect)
    _root.add_child(transition_overlay)

    var loading := CanvasLayer.new()
    loading.name = "LoadingOverlay"
    _root.add_child(loading)

    # Cursor manager for reactive updates
    _cursor = M_CursorManager.new()
    _root.add_child(_cursor)
    await get_tree().process_frame

    # Scene manager
    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    _root.add_child(_manager)

    # Pause system (coordinates cursor state with scene type)
    _pause_system = M_PauseManager.new()
    _root.add_child(_pause_system)
    await get_tree().process_frame

func after_each() -> void:
    _root = null
    _store = null
    _cursor = null
    _pause_system = null
    _manager = null

## MENU/UI scenes should set cursor unlocked + visible; GAMEPLAY should lock + hide
func test_cursor_updates_on_scene_state_changes() -> void:
    # MENU: main_menu
    _store.dispatch(U_SceneActions.transition_completed(StringName("main_menu")))
    await wait_physics_frames(1)  # State store batches
    await wait_physics_frames(1)  # M_PauseManager reacts

    assert_false(_cursor.is_cursor_locked(), "Cursor should be unlocked in UI/menu scenes")
    assert_true(_cursor.is_cursor_visible(), "Cursor should be visible in UI/menu scenes")

    # GAMEPLAY: use a test gameplay scene (scene1 is registered as gameplay)
    _store.dispatch(U_SceneActions.transition_completed(StringName("scene1")))
    await wait_physics_frames(1)  # State store batches
    await wait_physics_frames(1)  # M_PauseManager reacts

    assert_true(_cursor.is_cursor_locked(), "Cursor should be locked in gameplay scenes")
    assert_false(_cursor.is_cursor_visible(), "Cursor should be hidden in gameplay scenes")

## Test cursor remains visible in MENU scene after popping overlay
## Reproduces bug: cursor hidden when returning to main menu from pause menu
func test_cursor_visible_after_popping_overlay_from_menu_scene() -> void:
    # Given: We're in the main_menu scene (MENU type)
    _store.dispatch(U_SceneActions.transition_completed(StringName("main_menu")))
    await wait_physics_frames(1)

    # Verify initial state: cursor should be visible in menu
    assert_false(_cursor.is_cursor_locked(), "Cursor should be unlocked in main menu")
    assert_true(_cursor.is_cursor_visible(), "Cursor should be visible in main menu")

    # When: Push pause menu overlay
    _manager.push_overlay(StringName("pause_menu"))
    await wait_physics_frames(2)

    # Cursor should still be visible (pause overlay shows cursor)
    assert_false(_cursor.is_cursor_locked(), "Cursor should be unlocked with pause overlay")
    assert_true(_cursor.is_cursor_visible(), "Cursor should be visible with pause overlay")

    # When: Pop the pause menu overlay (simulating "return to main menu")
    _manager.pop_overlay()
    await wait_physics_frames(2)

    # Then: Cursor should STILL be visible because we're in a MENU scene
    # BUG: Currently fails - cursor gets hidden because _update_pause_state()
    # doesn't check scene type when overlay_count == 0
    assert_false(_cursor.is_cursor_locked(), "Cursor should remain unlocked after popping overlay from menu")
    assert_true(_cursor.is_cursor_visible(), "Cursor should remain visible after popping overlay from menu")

