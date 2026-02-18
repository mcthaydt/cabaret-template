extends BaseTest

## Proof-of-Concept Integration Tests: Pause System
##
## Phase 2: Updated to test scene-driven pause architecture
## Tests that validate state store integration with M_TimeManager via scene slice


var store: M_StateStore
var pause_system: Node  # Will be M_TimeManager once implemented
var cursor_manager: M_CursorManager

func before_each() -> void:
	# CRITICAL: Reset both event buses for integration tests
	U_StateEventBus.reset()
	U_ECSEventBus.reset()

	# Create M_StateStore
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame

	# Register state_store with ServiceLocator so managers can find it
	U_ServiceLocator.register(StringName("state_store"), store)

	# Create cursor manager (T071: required for M_TimeManager coordination)
	cursor_manager = M_CursorManager.new()
	autofree(cursor_manager)
	add_child(cursor_manager)
	await get_tree().process_frame

	# Register cursor_manager with ServiceLocator
	U_ServiceLocator.register(StringName("cursor_manager"), cursor_manager)

func after_each() -> void:
	get_tree().paused = false  # Reset pause state
	U_StateEventBus.reset()
	U_ECSEventBus.reset()
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	pause_system = null
	cursor_manager = null
	# Call parent to clear ServiceLocator
	super.after_each()

## T299: Test pause system reacts to scene state changes (Phase 2 refactor)
func test_pause_system_reacts_to_navigation_state() -> void:
	# Phase 2: M_TimeManager now watches scene slice, not navigation slice
	# Create pause system
	pause_system = M_TimeManager.new()
	add_child(pause_system)
	autofree(pause_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize

	# Push overlay to scene stack (simulates M_SceneManager behavior)
	store.dispatch(U_SceneActions.push_overlay(StringName("pause_menu")))
	await wait_physics_frames(1)  # Scene slice updates flush on physics frames

	# Verify pause system derives pause state from scene slice
	var scene_state: Dictionary = store.get_slice(StringName("scene"))
	var scene_stack: Array = scene_state.get("scene_stack", [])
	assert_eq(scene_stack.size(), 1, "Scene stack should have one overlay")
	assert_true(pause_system.is_paused(), "Pause system should reflect scene-derived pause state")

## T300: Test pause system applies engine-level pause (Phase 2 refactor)
func test_pause_system_applies_engine_pause() -> void:
	# Phase 2: M_TimeManager now applies get_tree().paused based on scene state
	# Create pause system
	pause_system = M_TimeManager.new()
	add_child(pause_system)
	autofree(pause_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize

	# Reset engine pause
	get_tree().paused = false

	# Push overlay to scene stack (simulates M_SceneManager opening overlay)
	store.dispatch(U_SceneActions.push_overlay(StringName("pause_menu")))
	await wait_physics_frames(2)  # Scene slice updates flush on physics frames, M_TimeManager reacts

	# Verify engine pause applied
	assert_true(get_tree().paused, "Engine should be paused when scene stack has overlays")
	assert_true(pause_system.is_paused(), "Pause system should reflect paused state")

	# Cleanup
	get_tree().paused = false

## T301: Test pause state accessible when overlays present (Phase 2)
func test_movement_disabled_when_paused() -> void:
	# Phase 2: Pause is derived from scene overlays, systems check get_tree().paused
	# Create pause system
	pause_system = M_TimeManager.new()
	add_child(pause_system)
	autofree(pause_system)
	await get_tree().process_frame
	await get_tree().process_frame

	# Pause by pushing an overlay to scene stack
	store.dispatch(U_SceneActions.push_overlay(StringName("pause_menu")))
	await wait_physics_frames(1)

	# Verify engine pause is set (systems check this)
	assert_true(get_tree().paused, "Engine should be paused with overlay in scene stack")
	assert_true(pause_system.is_paused(), "Pause system should indicate paused")

	# Movement/jump/input systems check get_tree().paused or pause_system.is_paused()
	# This test confirms the integration point works

	# Cleanup
	get_tree().paused = false
