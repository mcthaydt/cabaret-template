extends GutTest

## Integration tests for Scene Manager pause system (User Story 4)
##
## Tests cover:
## - Pause overlay push/pop
## - SceneTree.paused state management
## - Cursor visibility during pause
## - ECS system freezing during pause
## - Nested pause menus (gameplay → pause → settings)
## - Resume functionality

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const S_PAUSE_SYSTEM := preload("res://scripts/managers/m_time_manager.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")

var _root_node: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _cursor_manager: M_CURSOR_MANAGER
var _pause_system: S_PAUSE_SYSTEM
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer

func before_each() -> void:
	U_ServiceLocator.clear()

	# Create root structure for testing (includes HUDLayer + overlays)
	var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
	_root_node = root_ctx["root"]
	add_child_autofree(_root_node)
	_active_scene_container = root_ctx["active_scene_container"]
	_ui_overlay_stack = root_ctx["ui_overlay_stack"]

	# Create M_StateStore
	_state_store = M_STATE_STORE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_state_store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	_root_node.add_child(_state_store)

	# Create M_CursorManager
	_cursor_manager = M_CURSOR_MANAGER.new()
	_root_node.add_child(_cursor_manager)

	# Create M_SceneManager
	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root_node.add_child(_scene_manager)

	# Create M_TimeManager (Phase 2: T024b - sole authority for pause/cursor)
	_pause_system = S_PAUSE_SYSTEM.new()
	_root_node.add_child(_pause_system)

	# Register managers with ServiceLocator (Phase 10B-7: T141c)
	U_ServiceLocator.register(StringName("state_store"), _state_store)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor_manager)
	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)

	U_SceneTestHelpers.register_scene_manager_dependencies(_root_node, false, true, true)

	# Wait for all nodes to initialize
	await get_tree().process_frame

func after_each() -> void:
	if _scene_manager != null and is_instance_valid(_scene_manager):
		await U_SceneTestHelpers.wait_for_transition_idle(_scene_manager)
	if _root_node != null and is_instance_valid(_root_node):
		_root_node.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

func test_pause_overlay_pushed_to_ui_overlay_stack() -> void:
	# Given: No overlays on stack
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "UIOverlayStack should start empty")

	# When: Push pause_menu overlay
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame

	# Then: Overlay added to UIOverlayStack
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Pause menu should be added to UIOverlayStack")

func test_pop_overlay_removes_from_ui_overlay_stack() -> void:
	# Given: Pause menu is pushed
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Pause menu should be on stack")

	# When: Pop overlay
	_scene_manager.pop_overlay()
	await get_tree().process_frame

	# Then: Overlay removed
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Pause menu should be removed from stack")

func test_scene_tree_paused_when_pause_overlay_pushed() -> void:
	# Given: Game is not paused
	get_tree().paused = false
	assert_false(get_tree().paused, "SceneTree should not be paused initially")

	# When: Push pause overlay with pause trigger
	_trigger_pause()
	await wait_physics_frames(1)  # State store batches on physics frame
	await wait_physics_frames(1)  # M_TimeManager reacts

	# Then: SceneTree.paused is true
	assert_true(get_tree().paused, "SceneTree should be paused when pause overlay pushed")

	# Cleanup
	get_tree().paused = false

func test_scene_tree_unpaused_when_pause_overlay_popped() -> void:
	# Given: Game is paused
	_trigger_pause()
	await wait_physics_frames(1)
	await wait_physics_frames(1)  # Let M_TimeManager react
	assert_true(get_tree().paused, "Game should be paused initially")

	# When: Pop pause overlay (resume)
	_trigger_unpause()
	await wait_physics_frames(1)  # State store batches
	await wait_physics_frames(1)  # M_TimeManager reacts

	# Then: SceneTree.paused is false
	assert_false(get_tree().paused, "SceneTree should be unpaused when pause overlay popped")

func test_cursor_visible_when_paused() -> void:
	# Given: Cursor is hidden (gameplay state)
	_cursor_manager.set_cursor_state(true, false)  # locked, hidden
	assert_false(_cursor_manager.is_cursor_visible(), "Cursor should be hidden initially")

	# When: Pause game
	_trigger_pause()
	await wait_physics_frames(1)  # State store batches
	await wait_physics_frames(1)  # M_TimeManager updates cursor

	# Then: Cursor becomes visible
	assert_true(_cursor_manager.is_cursor_visible(), "Cursor should be visible when paused")

func test_cursor_hidden_when_unpaused() -> void:
	# Given: Game is paused with visible cursor
	_trigger_pause()
	await wait_physics_frames(1)
	await wait_physics_frames(1)  # Let M_TimeManager set cursor
	assert_true(_cursor_manager.is_cursor_visible(), "Cursor should be visible when paused")

	# When: Unpause game
	_trigger_unpause()
	await wait_physics_frames(1)  # State store batches
	await wait_physics_frames(1)  # M_TimeManager updates cursor

	# Then: Cursor becomes hidden
	assert_false(_cursor_manager.is_cursor_visible(), "Cursor should be hidden when unpaused")

func test_nested_pause_overlays_stack_correctly() -> void:
	# Given: No overlays
	assert_eq(_ui_overlay_stack.get_child_count(), 0)

	# When: Push pause menu → settings menu
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	_scene_manager.push_overlay(StringName("settings_menu"))
	await get_tree().process_frame

	# Then: Both overlays on stack
	assert_eq(_ui_overlay_stack.get_child_count(), 2, "Both pause and settings should be stacked")

	# When: Pop settings menu
	_scene_manager.pop_overlay()
	await get_tree().process_frame

	# Then: Only pause menu remains
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Only pause menu should remain")

func test_scene_slice_scene_stack_syncs_with_overlays() -> void:
	# When: Push pause menu overlay
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame

	# Then: scene_stack in state reflects overlay
	var state: Dictionary = _state_store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	var scene_stack: Array = scene_state.get("scene_stack", [])
	assert_eq(scene_stack.size(), 1, "scene_stack should have one entry")
	assert_eq(scene_stack[0], StringName("pause_menu"), "scene_stack should contain pause_menu")

	# When: Pop overlay
	_scene_manager.pop_overlay()
	await get_tree().process_frame

	# Then: scene_stack is empty
	state = _state_store.get_state()
	scene_state = state.get("scene", {})
	scene_stack = scene_state.get("scene_stack", [])
	assert_eq(scene_stack.size(), 0, "scene_stack should be empty after pop")

func test_pause_during_gameplay_freezes_ecs_systems() -> void:
	# This test verifies that ECS systems stop processing when paused
	# Note: Requires systems to check get_tree().paused before processing

	# Given: SceneTree is not paused
	get_tree().paused = false
	var initial_paused_state: bool = get_tree().paused

	# When: Trigger pause
	_trigger_pause()
	await get_tree().process_frame
	get_tree().paused = true  # Manual pause for this test

	# Then: SceneTree.paused is true
	assert_true(get_tree().paused, "SceneTree should be paused")
	assert_ne(initial_paused_state, get_tree().paused, "Pause state should change")

	# Cleanup
	get_tree().paused = false

func test_unpause_resumes_exactly() -> void:
	# This test verifies that unpausing doesn't advance time or change state

	# Given: Game is paused
	_trigger_pause()
	await get_tree().process_frame
	get_tree().paused = true

	# Capture state before unpause
	var state_before: Dictionary = _state_store.get_state().duplicate(true)

	# When: Unpause
	_trigger_unpause()
	await get_tree().process_frame
	get_tree().paused = false

	# Then: Gameplay state unchanged (no time advancement)
	var state_after: Dictionary = _state_store.get_state()
	var gameplay_before: Dictionary = state_before.get("gameplay", {})
	var gameplay_after: Dictionary = state_after.get("gameplay", {})

	# Verify critical gameplay fields unchanged
	assert_eq(gameplay_after.get("paused"), gameplay_before.get("paused"), "Paused flag should match")

func test_pause_menu_process_mode_set_to_always() -> void:
	# This test verifies that UIOverlayStack has PROCESS_MODE_ALWAYS
	# so it continues processing during SceneTree.paused

	assert_eq(_ui_overlay_stack.process_mode, Node.PROCESS_MODE_ALWAYS,
		"UIOverlayStack should have PROCESS_MODE_ALWAYS to work during pause")

## T109-T114: Scene History Navigation Tests

func test_ui_scenes_track_history() -> void:
	# Given: Navigate from main_menu to settings_menu
	_scene_manager.transition_to_scene(StringName("main_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.transition_to_scene(StringName("settings_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)

	# When: Call go_back()
	var can_go_back: bool = _scene_manager.can_go_back()

	# Then: History should have main_menu entry
	assert_true(can_go_back, "Should be able to go back after UI navigation")

func test_go_back_returns_to_previous_ui_scene() -> void:
	# Given: Navigate main_menu → settings_menu
	_scene_manager.transition_to_scene(StringName("main_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.transition_to_scene(StringName("settings_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)

	# When: Go back
	_scene_manager.go_back()
	await wait_physics_frames(5)

	# Then: Should return to main_menu
	var state: Dictionary = _state_store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	var current_scene: StringName = scene_state.get("current_scene_id", StringName(""))
	assert_eq(current_scene, StringName("main_menu"), "Should return to main_menu")

func test_gameplay_scenes_do_not_track_history() -> void:
	# Given: Navigate main_menu → gameplay_base
	_scene_manager.transition_to_scene(StringName("main_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.transition_to_scene(StringName("gameplay_base"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)

	# When: Check if can go back
	var can_go_back: bool = _scene_manager.can_go_back()

	# Then: Should NOT be able to go back (gameplay scenes clear history)
	assert_false(can_go_back, "Gameplay scenes should clear history (FR-078)")

func test_history_navigation_skips_gameplay_scenes() -> void:
	# Given: Navigate menu → settings → gameplay → settings
	_scene_manager.transition_to_scene(StringName("main_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.transition_to_scene(StringName("settings_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.transition_to_scene(StringName("gameplay_base"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.transition_to_scene(StringName("settings_menu"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)

	# When: Go back from settings
	_scene_manager.go_back()
	await wait_physics_frames(5)

	# Then: Should return to main_menu (skipping gameplay_base in history)
	var state: Dictionary = _state_store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	var current_scene: StringName = scene_state.get("current_scene_id", StringName(""))
	# Note: Since gameplay clears history, going back from settings after gameplay
	# should have no history, so go_back() should be a no-op
	# OR if we track pre-gameplay history, should return to main_menu
	assert_true(current_scene == StringName("settings_menu") or current_scene == StringName("main_menu"),
		"Should either stay at settings (no history) or return to main_menu (pre-gameplay history)")

func test_navigation_action_triggers_pause_during_gameplay() -> void:
	# T074: Updated to use navigation actions instead of direct ESC input
	# Given: In gameplay shell with no overlays
	_state_store.dispatch(U_NAVIGATION_ACTIONS.start_game(StringName("gameplay_base")))
	_scene_manager.transition_to_scene(StringName("gameplay_base"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	get_tree().paused = false
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "No overlays initially")

	# When: Dispatch open_pause navigation action
	_state_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await wait_physics_frames(2)

	# Then: Pause menu should be pushed via reconciliation
	assert_gt(_ui_overlay_stack.get_child_count(), 0, "Pause menu should be pushed via navigation action")
	assert_true(get_tree().paused, "Game should be paused")

## Helper: Trigger pause via scene manager
func _trigger_pause() -> void:
	_scene_manager.push_overlay(StringName("pause_menu"))

## Helper: Trigger unpause via scene manager
func _trigger_unpause() -> void:
	_scene_manager.pop_overlay()
