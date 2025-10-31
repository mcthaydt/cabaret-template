extends GutTest

## Integration test: Settings replaces Pause (no overlay stacking)

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")

var _root_node: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _cursor_manager: M_CURSOR_MANAGER
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer

func before_each() -> void:
	_root_node = Node.new()
	add_child_autofree(_root_node)

	_state_store = M_STATE_STORE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_root_node.add_child(_state_store)

	_cursor_manager = M_CURSOR_MANAGER.new()
	_root_node.add_child(_cursor_manager)

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

	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root_node.add_child(_scene_manager)

	await get_tree().process_frame

func test_settings_replaces_pause_and_returns_properly() -> void:
	# Given: In gameplay scene with pause overlay visible
	_scene_manager.transition_to_scene(StringName("gameplay_base"), "instant", M_SCENE_MANAGER.Priority.HIGH)
	await wait_physics_frames(5)
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Pause overlay should be shown")

	# When: Open settings from pause (should switch to settings scene and hide pause)
	_scene_manager.open_settings_from_pause()
	await wait_physics_frames(5)

	# Then: Overlay stack is empty, current_scene is settings_menu
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Pause overlay should be removed while in settings")
	var state: Dictionary = _state_store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	var current_scene: StringName = scene_state.get("current_scene_id", StringName(""))
	assert_eq(current_scene, StringName("settings_menu"), "Should be in settings scene")

	# When: Back from settings
	_scene_manager.resume_from_settings()
	await wait_physics_frames(5)

	# Then: Back to gameplay and pause overlay restored
	state = _state_store.get_state()
	scene_state = state.get("scene", {})
	current_scene = scene_state.get("current_scene_id", StringName(""))
	assert_eq(current_scene, StringName("gameplay_base"), "Should return to gameplay scene")
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Pause overlay should be restored after returning from settings")

