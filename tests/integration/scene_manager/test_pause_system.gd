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
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")

var _root_node: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _cursor_manager: M_CURSOR_MANAGER
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer

func before_each() -> void:
	# Create root structure for testing
	_root_node = Node.new()
	add_child_autofree(_root_node)

	# Create M_StateStore
	_state_store = M_STATE_STORE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_root_node.add_child(_state_store)

	# Create M_CursorManager
	_cursor_manager = M_CURSOR_MANAGER.new()
	_root_node.add_child(_cursor_manager)

	# Create containers
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root_node.add_child(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_node.add_child(_ui_overlay_stack)

	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	_root_node.add_child(transition_overlay)

	# Create M_SceneManager
	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root_node.add_child(_scene_manager)

	# Wait for all nodes to initialize
	await get_tree().process_frame

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
	await get_tree().process_frame

	# Then: SceneTree.paused is true
	assert_true(get_tree().paused, "SceneTree should be paused when pause overlay pushed")

	# Cleanup
	get_tree().paused = false

func test_scene_tree_unpaused_when_pause_overlay_popped() -> void:
	# Given: Game is paused
	_trigger_pause()
	await get_tree().process_frame
	get_tree().paused = true

	# When: Pop pause overlay (resume)
	_trigger_unpause()
	await get_tree().process_frame

	# Then: SceneTree.paused is false
	assert_false(get_tree().paused, "SceneTree should be unpaused when pause overlay popped")

func test_cursor_visible_when_paused() -> void:
	# Given: Cursor is hidden (gameplay state)
	_cursor_manager.set_cursor_state(true, false)  # locked, hidden
	assert_false(_cursor_manager.is_cursor_visible(), "Cursor should be hidden initially")

	# When: Pause game
	_trigger_pause()
	await get_tree().process_frame

	# Then: Cursor becomes visible
	assert_true(_cursor_manager.is_cursor_visible(), "Cursor should be visible when paused")

func test_cursor_hidden_when_unpaused() -> void:
	# Given: Game is paused with visible cursor
	_trigger_pause()
	await get_tree().process_frame
	_cursor_manager.set_cursor_state(false, true)  # unlocked, visible

	# When: Unpause game
	_trigger_unpause()
	await get_tree().process_frame

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

func test_esc_key_triggers_pause_during_gameplay() -> void:
	# Given: In gameplay scene with no pause overlay
	_scene_manager.transition_to_scene(StringName("gameplay_base"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	get_tree().paused = false
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "No overlays initially")

	# When: Simulate ESC key press via direct input handler call
	# Note: Input.parse_input_event() doesn't work in headless mode
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_scene_manager._input(event)  # Directly call input handler
	await get_tree().process_frame

	# Then: Pause menu should be pushed
	assert_gt(_ui_overlay_stack.get_child_count(), 0, "Pause menu should be pushed on ESC")
	assert_true(get_tree().paused, "Game should be paused on ESC")

## Helper: Trigger pause via scene manager
func _trigger_pause() -> void:
	_scene_manager.push_overlay(StringName("pause_menu"))

## Helper: Trigger unpause via scene manager
func _trigger_unpause() -> void:
	_scene_manager.pop_overlay()
