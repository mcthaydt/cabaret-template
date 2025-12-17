extends BaseTest

## Unit tests for overlay stack/state synchronization on M_SceneManager startup

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")
const M_CursorManager := preload("res://scripts/managers/m_cursor_manager.gd")
const M_SpawnManager := preload("res://scripts/managers/m_spawn_manager.gd")
const M_CameraManager := preload("res://scripts/managers/m_camera_manager.gd")
const M_PauseManager := preload("res://scripts/managers/m_pause_manager.gd")

var _store: M_StateStore
var _ui_overlay_stack: CanvasLayer
var _active_scene_container: Node
var _transition_overlay: CanvasLayer
var _cursor_manager: M_CursorManager
var _spawn_manager: M_SpawnManager
var _camera_manager: M_CameraManager
var _pause_system: M_PauseManager

func before_each() -> void:
	# Minimal scene tree structure expected by M_SceneManager
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	add_child_autofree(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	add_child_autofree(_ui_overlay_stack)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	_transition_overlay.add_child(color_rect)
	add_child_autofree(_transition_overlay)

	# Loading overlay required by manager
	var loading_overlay := CanvasLayer.new()
	loading_overlay.name = "LoadingOverlay"
	add_child_autofree(loading_overlay)

	# Provide required managers to avoid warnings/errors on _ready
	_cursor_manager = M_CursorManager.new()
	add_child_autofree(_cursor_manager)

	_spawn_manager = M_SpawnManager.new()
	add_child_autofree(_spawn_manager)
	await get_tree().process_frame

	_camera_manager = M_CameraManager.new()
	add_child_autofree(_camera_manager)
	await get_tree().process_frame

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	# Register all managers with ServiceLocator so they can find each other
	U_ServiceLocator.register(StringName("state_store"), _store)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)
	U_ServiceLocator.register(StringName("camera_manager"), _camera_manager)

	# Create M_PauseManager to apply pause based on scene state
	_pause_system = M_PauseManager.new()
	add_child_autofree(_pause_system)
	await get_tree().process_frame

	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)

func after_each() -> void:
	get_tree().paused = false  # Reset pause state
	_store = null
	_ui_overlay_stack = null
	_active_scene_container = null
	_transition_overlay = null
	_pause_system = null
	# Call parent to clear ServiceLocator
	super.after_each()

## When UIOverlayStack already has overlays, manager should mirror to state
func test_syncs_state_from_preexisting_ui_overlays() -> void:
	# Arrange: two overlay nodes already present with scene_id metadata
	var overlay1 := Node.new()
	overlay1.set_meta(StringName("_scene_manager_overlay_scene_id"), StringName("pause_menu"))
	_ui_overlay_stack.add_child(overlay1)
	autofree(overlay1)

	var overlay2 := Node.new()
	overlay2.set_meta(StringName("_scene_manager_overlay_scene_id"), StringName("settings_menu"))
	_ui_overlay_stack.add_child(overlay2)
	autofree(overlay2)

	# Act: create scene manager (triggers _sync_overlay_stack_state in _ready)
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	await get_tree().process_frame
	await get_tree().physics_frame  # Allow M_PauseManager to react to scene state update

	# Assert: scene slice reflects UI overlay order and tree is paused
	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	var stack: Array = scene_state.get("scene_stack", [])
	assert_eq(stack.size(), 2, "State should mirror two overlays from UI")
	assert_eq(StringName(stack[0]), StringName("pause_menu"))
	assert_eq(StringName(stack[1]), StringName("settings_menu"))
	assert_true(get_tree().paused, "Tree should be paused when overlays exist")

## When state has overlays but UI is empty, manager should clear state
func test_clears_stale_state_when_ui_empty() -> void:
	# Arrange: push two overlays into state BEFORE manager is created
	_store.dispatch(U_SceneActions.push_overlay(StringName("pause_menu")))
	_store.dispatch(U_SceneActions.push_overlay(StringName("settings_menu")))
	await get_tree().physics_frame

	# UI overlay stack intentionally left empty

	# Act: create manager → should reconcile and clear state stack
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	await get_tree().process_frame
	# Extra frame for pause system's _process() polling to sync
	await get_tree().process_frame

	# Assert: scene stack cleared and tree unpaused
	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	var stack: Array = scene_state.get("scene_stack", [])
	assert_eq(stack.size(), 0, "Manager should clear stale overlay state when UI has none")
	assert_false(get_tree().paused, "Tree should be unpaused without overlays")

## When popping a child overlay, focus should return to the next overlay below it
func test_restores_focus_to_underlying_overlay_after_pop() -> void:
	# Arrange: two overlays already on the stack (pause below settings)
	var pause_overlay := Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_meta(StringName("_scene_manager_overlay_scene_id"), StringName("pause_menu"))
	var pause_button := Button.new()
	pause_button.name = "ResumeButton"
	pause_overlay.add_child(pause_button)
	_ui_overlay_stack.add_child(pause_overlay)
	autofree(pause_overlay)

	var settings_overlay := Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_meta(StringName("_scene_manager_overlay_scene_id"), StringName("settings_menu"))
	var settings_button := Button.new()
	settings_button.name = "BackButton"
	settings_overlay.add_child(settings_button)
	_ui_overlay_stack.add_child(settings_overlay)
	autofree(settings_overlay)

	# Act: create manager (syncs existing overlays) and focus top overlay
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	await get_tree().process_frame

	settings_button.grab_focus()
	assert_true(settings_button.has_focus(), "Precondition: top overlay should own focus")

	# Pop top overlay; focus should move to pause overlay button
	manager.pop_overlay()
	await get_tree().process_frame

	var focus_owner := get_viewport().gui_get_focus_owner()
	assert_not_null(focus_owner, "Focus should be restored to a control")
	assert_eq(focus_owner, pause_button, "Focus should move to the underlying overlay's first focusable")
