extends GutTest

## Integration test: prevent ui_accept leaking across "Quit to Menu" transitions.
##
## Repro:
## - Start gameplay
## - Open pause overlay
## - Focus Quit button
## - Press ui_accept
## - Transition back to main menu
## Bug: same accept event can immediately activate focused Continue and dispatch save/load_started.

const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const RS_DebugInitialState := preload("res://scripts/state/resources/rs_debug_initial_state.gd")
const RS_SaveInitialState := preload("res://scripts/state/resources/rs_save_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const M_CursorManager := preload("res://scripts/managers/m_cursor_manager.gd")
const M_SpawnManager := preload("res://scripts/managers/m_spawn_manager.gd")
const M_CameraManager := preload("res://scripts/managers/m_camera_manager.gd")
const M_PauseManager := preload("res://scripts/managers/m_pause_manager.gd")

var _store: M_StateStore
var _scene_manager: M_SceneManager
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _dispatched: Array[Dictionary] = []

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	_cleanup_save_files()

	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	add_child_autofree(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_autofree(_ui_overlay_stack)

	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	transition_overlay.add_child(color_rect)
	add_child_autofree(transition_overlay)

	var loading_overlay := CanvasLayer.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_autofree(loading_overlay)

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_debug_logging = false
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	_store.debug_initial_state = RS_DebugInitialState.new()
	_store.save_initial_state = RS_SaveInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	U_ServiceLocator.register(StringName("state_store"), _store)

	var cursor_manager := M_CursorManager.new()
	add_child_autofree(cursor_manager)
	await get_tree().process_frame

	var spawn_manager := M_SpawnManager.new()
	add_child_autofree(spawn_manager)
	await get_tree().process_frame

	var camera_manager := M_CameraManager.new()
	add_child_autofree(camera_manager)
	await get_tree().process_frame

	U_ServiceLocator.register(StringName("cursor_manager"), cursor_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), spawn_manager)
	U_ServiceLocator.register(StringName("camera_manager"), camera_manager)

	var pause_manager := M_PauseManager.new()
	add_child_autofree(pause_manager)
	await get_tree().process_frame
	U_ServiceLocator.register(StringName("pause_manager"), pause_manager)

	_dispatched.clear()
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		_dispatched.append(action)
	)

	_scene_manager = M_SceneManager.new()
	_scene_manager.skip_initial_scene_load = true
	add_child_autofree(_scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)
	await get_tree().process_frame

func after_each() -> void:
	get_tree().paused = false
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	_cleanup_save_files()
	_store = null
	_scene_manager = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_dispatched.clear()

func _cleanup_save_files() -> void:
	for i in range(1, 4):
		U_SaveManager.delete_slot(i)
	var autosave_path := U_SaveManager.get_auto_slot_path()
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)
	if FileAccess.file_exists(U_SaveManager.DEFAULT_LEGACY_PATH):
		DirAccess.remove_absolute(U_SaveManager.DEFAULT_LEGACY_PATH)
	if FileAccess.file_exists(U_SaveManager.DEFAULT_LEGACY_BACKUP_PATH):
		DirAccess.remove_absolute(U_SaveManager.DEFAULT_LEGACY_BACKUP_PATH)

func _await_until(predicate: Callable, max_frames: int = 120) -> bool:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return false

func _has_action_type(action_type: StringName) -> bool:
	for action in _dispatched:
		if action.get("type", StringName("")) == action_type:
			return true
	return false

func test_quit_to_menu_does_not_trigger_continue_load_from_leaked_accept() -> void:
	# Ensure saves exist so Continue is visible and focusable.
	var state_for_save: Dictionary = _store.get_state()
	var scene_slice: Dictionary = state_for_save.get("scene", {})
	scene_slice["current_scene_id"] = StringName("scene1")
	state_for_save["scene"] = scene_slice
	var err: Error = U_SaveManager.save_to_slot(1, state_for_save, {})
	assert_eq(err, OK, "Test setup should write a save slot")

	# Start gameplay scene via navigation (lets SceneManager load exterior).
	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	var loaded_gameplay := await _await_until(func() -> bool:
		var scene_state: Dictionary = _store.get_slice(StringName("scene"))
		return scene_state.get("current_scene_id", StringName("")) == StringName("scene1")
	)
	assert_true(loaded_gameplay, "Should load gameplay scene before pausing")

	# Open pause menu overlay via navigation.
	_store.dispatch(U_NavigationActions.open_pause())
	var pause_overlay_ready := await _await_until(func() -> bool:
		return _ui_overlay_stack != null and _ui_overlay_stack.get_child_count() > 0
	)
	assert_true(pause_overlay_ready, "Pause overlay should be instantiated by SceneManager")

	var pause_menu_root: Node = _ui_overlay_stack.get_child(0)
	var quit_button: Button = pause_menu_root.find_child("QuitButton", true, false) as Button
	assert_not_null(quit_button, "Pause menu should contain QuitButton")
	quit_button.grab_focus()
	await get_tree().process_frame

	_dispatched.clear()

	# Simulate leaked accept across the transition boundary.
	# This mirrors the real bug: accept is still active when the main menu appears.
	Input.action_press("ui_accept")
	quit_button.pressed.emit()

	# Regression expectation: the GUI input gate must engage immediately when
	# navigation/return_to_main_menu is dispatched (same call stack as Quit pressed),
	# otherwise the in-flight accept can still reach the newly-focused Continue.
	var viewport := get_viewport()
	assert_not_null(viewport, "Viewport should exist for GUI gating checks")
	assert_true(viewport.gui_disable_input, "GUI input should be disabled immediately on Quit-to-Menu action dispatch")

	# Simulate the common real-world case: accept is a quick tap. Even after release,
	# the transition boundary must stay gated long enough that any delayed accept
	# press can't immediately activate Continue.
	Input.action_release("ui_accept")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(viewport.gui_disable_input, "GUI input gate should remain active for a few frames after Quit-to-Menu")

	# Wait for navigation to reach main_menu (SceneManager reconciliation).
	var reached_menu := await _await_until(func() -> bool:
		var nav: Dictionary = _store.get_slice(StringName("navigation"))
		return nav.get("shell", StringName("")) == StringName("main_menu")
	)
	assert_true(reached_menu, "Quit should switch navigation shell to main_menu")

	# Ensure main menu scene exists and Continue can be focused.
	var menu_ready := await _await_until(func() -> bool:
		if _active_scene_container == null:
			return false
		var found := _active_scene_container.find_child("ContinueButton", true, false) as Button
		return found != null
	, 60)
	assert_true(menu_ready, "Main menu scene should be loaded and expose ContinueButton")
	var continue_button: Button = _active_scene_container.find_child("ContinueButton", true, false) as Button
	assert_not_null(continue_button, "Main menu should contain ContinueButton for leak repro")
	continue_button.grab_focus()
	await get_tree().process_frame

	# If an "echo" accept event arrives while accept is still held, it must NOT activate Continue.
	var accept_echo := InputEventAction.new()
	accept_echo.action = "ui_accept"
	accept_echo.pressed = true
	accept_echo.strength = 1.0
	Input.parse_input_event(accept_echo)
	await get_tree().process_frame
	var accept_release := InputEventAction.new()
	accept_release.action = "ui_accept"
	accept_release.pressed = false
	accept_release.strength = 0.0
	Input.parse_input_event(accept_release)
	await get_tree().process_frame

	# Releasing accept should eventually release the GUI gate.
	var released_gate := await _await_until(func() -> bool:
		return not viewport.gui_disable_input
	, 120)
	assert_true(released_gate, "GUI input gate should release after ui_accept is released")

	# Any leaked accept should NOT auto-dispatch load_started from focused Continue.
	var saw_load_started := _has_action_type(U_SaveActions.ACTION_LOAD_STARTED)
	assert_false(saw_load_started, "Leaked ui_accept must not trigger Continue load_started after quitting to menu")
