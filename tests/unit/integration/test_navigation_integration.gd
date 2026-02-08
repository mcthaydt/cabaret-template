extends BaseTest


var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer
var _cursor_manager: M_CursorManager
var _spawn_manager: M_SpawnManager
var _camera_manager: M_CameraManager
var _pause_system: M_PauseManager

func before_each() -> void:
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

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	add_child_autofree(_loading_overlay)

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame
	U_ServiceLocator.register(StringName("state_store"), _store)

	_cursor_manager = M_CursorManager.new()
	add_child_autofree(_cursor_manager)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor_manager)

	_spawn_manager = M_SpawnManager.new()
	add_child_autofree(_spawn_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)

	_camera_manager = M_CameraManager.new()
	add_child_autofree(_camera_manager)
	U_ServiceLocator.register(StringName("camera_manager"), _camera_manager)

	# Register all managers with ServiceLocator so they can find each other
	# Create M_PauseManager to apply pause based on scene state
	_pause_system = M_PauseManager.new()
	add_child_autofree(_pause_system)
	await get_tree().process_frame

	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)

func after_each() -> void:
	get_tree().paused = false  # Reset pause state
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_loading_overlay = null
	_cursor_manager = null
	_spawn_manager = null
	_camera_manager = null
	_pause_system = null
	# Call parent to clear ServiceLocator
	super.after_each()

func test_navigation_open_and_close_pause_overlay() -> void:
	await _spawn_scene_manager()

	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	await _await_scene(StringName("scene1"))

	_store.dispatch(U_NavigationActions.open_pause())
	await wait_physics_frames(5)  # Allow time for navigation→scene bridging + M_PauseManager reaction

	assert_true(get_tree().paused, "Tree should pause when pause overlay opens")
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Pause overlay added to stack")
	assert_eq(_get_top_overlay_scene_id(), StringName("pause_menu"), "Pause overlay should be on top")

	_store.dispatch(U_NavigationActions.close_pause())
	await wait_physics_frames(3)

	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Pause overlay removed after close")
	assert_false(get_tree().paused, "Tree resumes when pause overlay closes")

func test_navigation_nested_overlay_returns_to_pause() -> void:
	await _spawn_scene_manager()

	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	await _await_scene(StringName("scene1"))

	_store.dispatch(U_NavigationActions.open_pause())
	await wait_physics_frames(2)

	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	await wait_physics_frames(3)

	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Settings overlay should replace pause as top overlay")
	assert_eq(_get_top_overlay_scene_id(), StringName("settings_menu"), "Settings overlay should be top-most")

	_store.dispatch(U_NavigationActions.close_top_overlay())
	await wait_physics_frames(2)

	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Settings overlay removed, pause restored as top overlay")
	assert_eq(_get_top_overlay_scene_id(), StringName("pause_menu"), "Pause overlay restored after return")

	_store.dispatch(U_NavigationActions.close_top_overlay())
	await wait_physics_frames(2)

	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Returning again resumes gameplay")

func test_navigation_retry_returns_to_last_gameplay_scene() -> void:
	await _spawn_scene_manager()

	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	await _await_scene(StringName("scene1"))

	_store.dispatch(U_NavigationActions.open_endgame(StringName("game_over")))
	await _await_scene(StringName("game_over"), 20)

	_store.dispatch(U_NavigationActions.retry())
	await _await_scene(StringName("scene1"), 20)

	var scene_state: Dictionary = _store.get_state().get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("scene1"), "Retry should restore last gameplay scene")

func test_navigation_victory_skip_flow() -> void:
	await _spawn_scene_manager()

	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	await _await_scene(StringName("scene1"))

	_store.dispatch(U_NavigationActions.open_endgame(StringName("victory")))
	await _await_scene(StringName("victory"), 20)

	_store.dispatch(U_NavigationActions.skip_to_credits())
	await _await_scene(StringName("credits"), 20)

	_store.dispatch(U_NavigationActions.skip_to_menu())
	await _await_scene(StringName("main_menu"), 20)

	var scene_state: Dictionary = _store.get_state().get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"), "Skip to menu should load main menu scene")


func test_sync_navigation_shell_does_not_override_pending_navigation() -> void:
	var manager := await _spawn_scene_manager()

	# Simulate navigation already requesting settings_menu while a previous
	# scene (e.g., touchscreen_settings) finishes loading.
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	nav_slice["shell"] = StringName("main_menu")
	nav_slice["base_scene_id"] = StringName("settings_menu")
	_store._state["navigation"] = nav_slice.duplicate(true)

	manager._set_navigation_pending_scene_id(StringName("settings_menu"))

	# A transition for the previous scene completes; SceneManager attempts to
	# sync navigation shell to that scene_id. This should NOT clobber the
	# pending navigation target (settings_menu).
	manager._sync_navigation_shell_with_scene(StringName("touchscreen_settings"))

	nav_slice = _store.get_slice(StringName("navigation"))
	assert_eq(
		nav_slice.get("base_scene_id"),
		StringName("settings_menu"),
		"Syncing shell for a previous scene must not override a newer pending navigation target"
	)

func test_sync_navigation_shell_clears_stale_pending_navigation() -> void:
	var manager := await _spawn_scene_manager()

	# Emulate runtime post-bootstrap state. This test does not transition scenes;
	# it focuses on the guard rails in _sync_navigation_shell_with_scene().
	manager._initial_navigation_synced = true
	manager._set_navigation_pending_scene_id(StringName("main_menu"))
	manager._active_transition_target = StringName("")  # Pending scene is not actively transitioning.

	# Navigation slice is stuck thinking main_menu is pending (stale) while a gameplay scene
	# completes loading via a manual transition (e.g., load-from-save).
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	nav_slice["shell"] = StringName("main_menu")
	nav_slice["base_scene_id"] = StringName("main_menu")
	_store._state[StringName("navigation")] = nav_slice.duplicate(true)

	# The loaded scene is gameplay; syncing should clear the stale pending target and
	# dispatch a navigation action to align shell/base_scene_id with the actual scene.
	manager._sync_navigation_shell_with_scene(StringName("scene1"))
	await wait_physics_frames(1)

	nav_slice = _store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("base_scene_id"), StringName("scene1"), "Stale pending navigation should not block shell sync")
	assert_eq(nav_slice.get("shell"), StringName("gameplay"), "Gameplay scene should run under gameplay shell")

func test_manual_transition_to_touchscreen_settings_aligns_navigation() -> void:
	var manager := await _spawn_scene_manager()

	# Emulate runtime post-bootstrap state: navigation already synced and no
	# pending navigation-driven transition. Tests use skip_initial_scene_load,
	# so we explicitly clear pending state and normalize navigation here.
	manager._initial_navigation_synced = true
	manager._set_navigation_pending_scene_id(StringName(""))

	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	nav_slice["shell"] = StringName("main_menu")
	nav_slice["base_scene_id"] = StringName("main_menu")
	nav_slice["overlay_stack"] = []
	nav_slice["overlay_return_stack"] = []
	nav_slice["active_menu_panel"] = StringName("menu/main")
	_store._state[StringName("navigation")] = nav_slice.duplicate(true)

	# Transition into settings_menu as a standalone UI scene (main menu flow).
	manager.transition_to_scene(StringName("settings_menu"), "instant", M_SceneManager.Priority.HIGH)
	await _await_scene(StringName("settings_menu"), 30)

	nav_slice = _store.get_slice(StringName("navigation"))
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var base_scene_id: StringName = U_NavigationSelectors.get_base_scene_id(nav_slice)

	assert_eq(shell, StringName("main_menu"), "Settings menu should run in main_menu shell")
	assert_eq(
		base_scene_id,
		StringName("settings_menu"),
		"Navigation base_scene_id should track settings_menu after manual transition"
	)

	# From settings_menu, transition directly to touchscreen_settings (main menu flow).
	manager.transition_to_scene(StringName("touchscreen_settings"), "instant", M_SceneManager.Priority.HIGH)
	await _await_scene(StringName("touchscreen_settings"), 30)

	nav_slice = _store.get_slice(StringName("navigation"))
	shell = U_NavigationSelectors.get_shell(nav_slice)
	base_scene_id = U_NavigationSelectors.get_base_scene_id(nav_slice)

	assert_eq(shell, StringName("main_menu"), "Touchscreen settings should run in main_menu shell")
	assert_eq(
		base_scene_id,
		StringName("touchscreen_settings"),
		"Navigation base_scene_id should track touchscreen_settings after manual transition"
	)

func _get_top_overlay_scene_id() -> StringName:
	if _ui_overlay_stack == null or _ui_overlay_stack.get_child_count() == 0:
		return StringName("")
	var manager := U_ServiceLocator.try_get_service(StringName("scene_manager")) as M_SceneManager
	if manager != null and is_instance_valid(manager):
		return manager._overlay_helper.get_top_overlay_id(_ui_overlay_stack)
	return StringName("")

func _spawn_scene_manager() -> M_SceneManager:
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	await get_tree().process_frame
	# Register scene_manager with ServiceLocator so other managers can find it
	U_ServiceLocator.register(StringName("scene_manager"), manager)
	return manager

func _await_scene(scene_id: StringName, limit_frames: int = 30) -> void:
	for _i in range(limit_frames):
		var state: Dictionary = _store.get_state()
		var scene_state: Dictionary = state.get("scene", {})
		if scene_state.get("current_scene_id") == scene_id:
			return
		await wait_physics_frames(1)
	assert_true(false, "Timed out waiting for scene_id %s" % scene_id)
