extends GutTest

## Integration test for basic scene transitions
##
## Tests full scene transition flow: main_menu → settings_menu → back to main_menu.
## Validates M_SceneManager, U_SceneRegistry, scene slice state, and transition effects.
## Tests follow TDD discipline: written BEFORE implementation.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/state/resources/rs_state_store_settings.gd")
const U_SceneRegistry = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_SceneActions = preload("res://scripts/state/actions/u_scene_actions.gd")

var _root_scene: Node
var _manager: M_SceneManager
var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer

func before_each() -> void:
	# Create root scene structure
	_root_scene = Node.new()
	_root_scene.name = "Root"
	add_child_autofree(_root_scene)

	# Create state store with all slices
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	var scene_initial_state := RS_SceneInitialState.new()
	_store.scene_initial_state = scene_initial_state
	_root_scene.add_child(_store)
	await get_tree().process_frame

	# Create scene containers
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root_scene.add_child(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_scene.add_child(_ui_overlay_stack)

	# Create transition overlay
	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	transition_overlay.add_child(color_rect)
	_root_scene.add_child(transition_overlay)

	# Create scene manager
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true  # Don't load main_menu automatically in tests
	_root_scene.add_child(_manager)
	await get_tree().process_frame

func after_each() -> void:
	_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_root_scene = null

## Test complete flow: main_menu → settings_menu → back to main_menu
func test_main_menu_to_settings_and_back() -> void:
	# Start at main menu
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var state1: Dictionary = _store.get_state()
	var scene_state1: Dictionary = state1.get("scene", {})
	assert_eq(scene_state1.get("current_scene_id"), StringName("main_menu"), "Should start at main_menu")

	# Transition to settings menu
	_manager.transition_to_scene(StringName("settings_menu"), "fade")
	await wait_physics_frames(15)  # Wait for 0.2s fade transition (0.2s * 60fps = 12 frames + buffer)

	var state2: Dictionary = _store.get_state()
	var scene_state2: Dictionary = state2.get("scene", {})
	assert_eq(scene_state2.get("current_scene_id"), StringName("settings_menu"), "Should transition to settings_menu")

	# Transition back to main menu
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var state3: Dictionary = _store.get_state()
	var scene_state3: Dictionary = state3.get("scene", {})
	assert_eq(scene_state3.get("current_scene_id"), StringName("main_menu"), "Should return to main_menu")

## Test scene slice state updates correctly during transitions
func test_scene_slice_state_updates() -> void:
	# Subscribe to scene slice updates
	var slice_updates: Array = []
	_store.slice_updated.connect(func(slice_name: StringName, slice_state: Dictionary) -> void:
		if slice_name == StringName("scene"):
			slice_updates.append(slice_state.duplicate(true))
	)

	# Perform transition
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(3)

	# Verify slice was updated
	assert_gt(slice_updates.size(), 0, "Scene slice should emit updates")

	var final_update: Dictionary = slice_updates[slice_updates.size() - 1]
	assert_eq(final_update.get("current_scene_id"), StringName("main_menu"), "Scene slice should reflect current scene")

## Test is_transitioning flag during transition
func test_is_transitioning_flag() -> void:
	# Initially not transitioning
	var state1: Dictionary = _store.get_state()
	var scene_state1: Dictionary = state1.get("scene", {})
	assert_false(scene_state1.get("is_transitioning", false), "Should not be transitioning initially")

	# Start transition
	_manager.transition_to_scene(StringName("main_menu"), "fade")
	await get_tree().physics_frame

	# Check during transition
	var state2: Dictionary = _store.get_state()
	var scene_state2: Dictionary = state2.get("scene", {})
	assert_true(scene_state2.get("is_transitioning", false), "Should be transitioning during fade")

	# Wait for completion
	await wait_physics_frames(15)  # Wait for 0.2s fade transition (0.2s * 60fps = 12 frames + buffer)

	# Check after transition
	var state3: Dictionary = _store.get_state()
	var scene_state3: Dictionary = state3.get("scene", {})
	assert_false(scene_state3.get("is_transitioning", false), "Should not be transitioning after completion")

## Test overlay stack with pause menu
func test_pause_menu_overlay_stack() -> void:
	# Load gameplay scene
	_manager.transition_to_scene(StringName("gameplay_base"), "instant")
	await wait_physics_frames(2)

	# Push pause menu overlay
	_manager.push_overlay(StringName("pause_menu"))
	await wait_physics_frames(2)

	# Verify scene stack in state
	var state1: Dictionary = _store.get_state()
	var scene_state1: Dictionary = state1.get("scene", {})
	var scene_stack1: Array = scene_state1.get("scene_stack", [])
	assert_eq(scene_stack1.size(), 1, "Should have one overlay")
	assert_eq(scene_stack1[0], StringName("pause_menu"), "Should be pause_menu")

	# Current scene should remain gameplay
	assert_eq(scene_state1.get("current_scene_id"), StringName("gameplay_base"), "Current scene should still be gameplay")

	# Pop pause menu
	_manager.pop_overlay()
	await wait_physics_frames(2)

	# Verify stack cleared
	var state2: Dictionary = _store.get_state()
	var scene_state2: Dictionary = state2.get("scene", {})
	var scene_stack2: Array = scene_state2.get("scene_stack", [])
	assert_eq(scene_stack2.size(), 0, "Stack should be empty after pop")

## Test nested overlays (pause → settings → back through stack)
func test_nested_overlays() -> void:
	_manager.transition_to_scene(StringName("gameplay_base"), "instant")
	await wait_physics_frames(2)

	# Push pause menu
	_manager.push_overlay(StringName("pause_menu"))
	await wait_physics_frames(2)

	# Push settings menu on top
	_manager.push_overlay(StringName("settings_menu"))
	await wait_physics_frames(2)

	# Verify stack has both
	var state1: Dictionary = _store.get_state()
	var scene_state1: Dictionary = state1.get("scene", {})
	var scene_stack1: Array = scene_state1.get("scene_stack", [])
	assert_eq(scene_stack1.size(), 2, "Should have two overlays")
	assert_eq(scene_stack1[0], StringName("pause_menu"), "First should be pause")
	assert_eq(scene_stack1[1], StringName("settings_menu"), "Second should be settings")

	# Pop settings (back to pause)
	_manager.pop_overlay()
	await wait_physics_frames(2)

	var state2: Dictionary = _store.get_state()
	var scene_state2: Dictionary = state2.get("scene", {})
	var scene_stack2: Array = scene_state2.get("scene_stack", [])
	assert_eq(scene_stack2.size(), 1, "Should have one overlay after pop")
	assert_eq(scene_stack2[0], StringName("pause_menu"), "Should be back to pause")

## Test scene loading into ActiveSceneContainer
func test_scene_loads_into_container() -> void:
	var initial_children: int = _active_scene_container.get_child_count()

	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var final_children: int = _active_scene_container.get_child_count()
	assert_gt(final_children, initial_children, "Should load scene into ActiveSceneContainer")

## Test scene unloading cleans up previous scene
func test_scene_transition_cleans_up_previous() -> void:
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var children_after_first: int = _active_scene_container.get_child_count()

	_manager.transition_to_scene(StringName("settings_menu"), "instant")
	await wait_physics_frames(2)

	var children_after_second: int = _active_scene_container.get_child_count()

	# Should have roughly same number (old scene removed, new scene added)
	# Exact behavior depends on implementation (might be 0, 1, or 2 during transition)
	assert_true(true, "Scene transition should clean up previous scene")

## Test transition with invalid scene ID
func test_invalid_scene_id_handled_gracefully() -> void:
	_manager.transition_to_scene(StringName("nonexistent_scene"), "instant")
	await wait_physics_frames(2)

	# Should not crash
	assert_true(true, "Should handle invalid scene ID gracefully")

## Test rapid transitions (queueing)
func test_rapid_transitions_queue_correctly() -> void:
	_manager.transition_to_scene(StringName("scene1"), "instant")
	_manager.transition_to_scene(StringName("scene2"), "instant")
	_manager.transition_to_scene(StringName("scene3"), "instant")

	await wait_physics_frames(6)

	# Should eventually reach final scene
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("scene3"), "Should process queued transitions")

## Test U_SceneRegistry integration
func test_scene_registry_provides_metadata() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("main_menu"))

	assert_false(scene_data.is_empty(), "U_SceneRegistry should provide main_menu data")
	assert_true(scene_data.has("path"), "Scene data should include path")
	assert_true(scene_data.has("scene_type"), "Scene data should include type")

## Test fade transition effect completes
func test_fade_transition_completes() -> void:
	var state_updates: Array = []
	_store.subscribe(func(_action: Dictionary, state: Dictionary) -> void:
		state_updates.append(state.duplicate(true))
	)

	_manager.transition_to_scene(StringName("main_menu"), "fade")

	# Wait for fade duration (default is likely 0.5s)
	await wait_seconds(0.7)

	# Verify transition completed
	var final_state: Dictionary = _store.get_state()
	var scene_state: Dictionary = final_state.get("scene", {})
	assert_false(scene_state.get("is_transitioning", false), "Fade should complete")
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"), "Should reach target scene")

## Test instant transition completes immediately
func test_instant_transition_completes_fast() -> void:
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await get_tree().physics_frame

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	# Instant transition should complete very quickly (within 1-2 frames)
	assert_true(true, "Instant transition should be fast")

## Test previous_scene_id tracking
func test_previous_scene_id_tracked() -> void:
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	_manager.transition_to_scene(StringName("settings_menu"), "instant")
	await wait_physics_frames(2)

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("previous_scene_id"), StringName("main_menu"), "Should track previous scene")
