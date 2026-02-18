extends GutTest

## Integration test for reactive cursor updates on scene changes

const M_TIME_MANAGER := preload("res://scripts/managers/m_time_manager.gd")

var _root: Node
var _store: M_StateStore
var _cursor: M_CursorManager
var _pause_system: Node
var _manager: M_SceneManager

func before_each() -> void:
    U_ServiceLocator.clear()

    var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
    _root = root_ctx["root"]
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
    # Register state store via ServiceLocator BEFORE managers run _ready()
    U_ServiceLocator.register(StringName("state_store"), _store)
    await get_tree().process_frame

    U_SceneTestHelpers.register_scene_manager_dependencies(_root, false, true, true)

    # Cursor manager for reactive updates
    _cursor = M_CursorManager.new()
    _root.add_child(_cursor)
    # Register cursor_manager for M_TimeManager discovery
    U_ServiceLocator.register(StringName("cursor_manager"), _cursor)
    await get_tree().process_frame

    # Scene manager
    _manager = M_SceneManager.new()
    _manager.skip_initial_scene_load = true
    _root.add_child(_manager)
    U_ServiceLocator.register(StringName("scene_manager"), _manager)

    # Pause system (coordinates cursor state with scene type)
    _pause_system = M_TIME_MANAGER.new()
    _root.add_child(_pause_system)
    U_ServiceLocator.register(StringName("pause_manager"), _pause_system)
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
    _cursor = null
    _pause_system = null
    _manager = null

## MENU/UI scenes should set cursor unlocked + visible; GAMEPLAY should lock + hide
func test_cursor_updates_on_scene_state_changes() -> void:
    # MENU: main_menu
    _store.dispatch(U_SceneActions.transition_completed(StringName("main_menu")))
    await wait_physics_frames(1)  # State store batches
    await wait_physics_frames(1)  # M_TimeManager reacts

    assert_false(_cursor.is_cursor_locked(), "Cursor should be unlocked in UI/menu scenes")
    assert_true(_cursor.is_cursor_visible(), "Cursor should be visible in UI/menu scenes")

    # GAMEPLAY: use a test gameplay scene (scene1 is registered as gameplay)
    _store.dispatch(U_SceneActions.transition_completed(StringName("scene1")))
    await wait_physics_frames(1)  # State store batches
    await wait_physics_frames(1)  # M_TimeManager reacts

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
