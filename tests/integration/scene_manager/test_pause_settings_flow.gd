extends GutTest

## Integration test: Settings overlay with return to Pause (Phase 6.5)
## Tests generic overlay navigation using push_overlay_with_return / pop_overlay_with_return

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const S_PAUSE_SYSTEM := preload("res://scripts/managers/m_pause_manager.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")

var _root_node: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _cursor_manager: M_CURSOR_MANAGER
var _pause_system: S_PAUSE_SYSTEM
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
	_root_node = root_ctx["root"]
	add_child_autofree(_root_node)
	_active_scene_container = root_ctx["active_scene_container"]
	_ui_overlay_stack = root_ctx["ui_overlay_stack"]

	# Create state store - register IMMEDIATELY after adding to tree
	# so other managers can find it in their _ready()
	_state_store = M_STATE_STORE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_state_store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	_root_node.add_child(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)

	U_SceneTestHelpers.register_scene_manager_dependencies(_root_node, false, true, true)

	# Create cursor manager - register immediately
	_cursor_manager = M_CURSOR_MANAGER.new()
	_root_node.add_child(_cursor_manager)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor_manager)

	# Create scene manager - register immediately
	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root_node.add_child(_scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)

	# Create M_PauseManager (Phase 2: T024b - sole authority for pause/cursor) - register immediately
	_pause_system = S_PAUSE_SYSTEM.new()
	_root_node.add_child(_pause_system)
	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)

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

func test_settings_with_return_to_pause_using_new_api() -> void:
	# Given: In gameplay with pause overlay visible
	_scene_manager.transition_to_scene(StringName("gameplay_base"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Pause overlay should be shown")

	# When: Open settings with return navigation (Phase 6.5 - REPLACE mode)
	# This pops pause, remembers it, then pushes settings
	_scene_manager.push_overlay_with_return(StringName("settings_menu"))
	await get_tree().process_frame

	# Then: Still one overlay (pause REPLACED with settings)
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (settings replaces pause)")
	# Verify the overlay is settings_menu
	var top_id := _scene_manager._overlay_helper.get_top_overlay_id(_ui_overlay_stack)
	assert_true(StringName(top_id) == StringName("settings_menu"), "Top overlay should be settings_menu")

	# When: Return from settings with automatic restoration (Phase 6.5)
	# This pops settings, then restores pause from return stack
	_scene_manager.pop_overlay_with_return()
	await get_tree().process_frame

	# Then: Back to one overlay (pause_menu automatically restored)
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have pause overlay after returning")
	top_id = _scene_manager._overlay_helper.get_top_overlay_id(_ui_overlay_stack)
	assert_true(StringName(top_id) == StringName("pause_menu"), "Top overlay should be pause_menu")
