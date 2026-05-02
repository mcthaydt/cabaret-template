extends GutTest

const I_SCENE_MANAGER := preload("res://scripts/core/interfaces/i_scene_manager.gd")

var _store: M_StateStore = null
var _input_handler: M_UIInputHandler = null
var _scene_manager_stub: TestSceneManagerStub = null

class TestSceneManagerStub extends I_SCENE_MANAGER:
	var suppress_pause: bool = false

	func is_transitioning() -> bool:
		return false

	func transition_to_scene(_scene_id: StringName, _transition_type: String = "fade", _priority: int = 0) -> void:
		pass

	func hint_preload_scene(_scene_path: String) -> void:
		pass

	func suppress_pause_for_current_frame() -> void:
		suppress_pause = true

	func is_pause_suppressed_for_current_frame() -> bool:
		return suppress_pause

	func push_overlay(_scene_id: StringName, _force: bool = false) -> void:
		pass

	func pop_overlay() -> void:
		pass

func before_each() -> void:
	U_StateHandoff.clear_all()
	_store = await _create_state_store()
	_scene_manager_stub = TestSceneManagerStub.new()
	add_child_autofree(_scene_manager_stub)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager_stub)
	_input_handler = await _create_input_handler()

func after_each() -> void:
	if _input_handler != null:
		_input_handler.queue_free()
	if _store != null:
		_store.queue_free()
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()


## GAMEPLAY CONTEXT TESTS

func test_gameplay_no_overlays_opens_pause() -> void:
	# Setup: gameplay shell, no overlays
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await wait_process_frames(2)

	# Action: press ui_pause (Start button)
	_simulate_ui_pause()
	await wait_process_frames(2)

	# Assert: pause overlay was added
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 1, "Should have one overlay after pause pressed in gameplay")
	assert_eq(overlay_stack[0], StringName("pause_menu"), "Should open pause menu")


func test_gameplay_no_overlays_cancel_does_nothing() -> void:
	# Setup: gameplay shell, no overlays
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await wait_process_frames(2)

	# Action: press ui_cancel (B button)
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: no overlay was added (cancel does NOT open pause)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 0, "B button should NOT open pause in gameplay with no overlays")


func test_gameplay_with_pause_closes_pause() -> void:
	# Setup: gameplay with pause overlay
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_pause())
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: overlay stack is empty (pause closed)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 0, "Should close pause overlay when cancel pressed in pause")


func test_gameplay_with_settings_overlay_closes_settings() -> void:
	# Setup: gameplay → pause → settings (return overlay)
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_pause())
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: settings closed, pause remains (RETURN_TO_PREVIOUS_OVERLAY)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 1, "Should return to pause overlay")
	assert_eq(overlay_stack[0], StringName("pause_menu"), "Pause should remain after settings closes")


func test_gameplay_with_gamepad_settings_resumes_gameplay() -> void:
	# Setup: gameplay → pause → gamepad_settings (resume overlay)
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_pause())
	_store.dispatch(U_NavigationActions.open_overlay(StringName("gamepad_settings")))
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: returns to settings overlay, game remains paused
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 1, "Should return to settings overlay when gamepad_settings closes")
	assert_eq(overlay_stack[0], StringName("pause_menu"), "Pause overlay should be active after gamepad_settings closes")
	assert_true(U_NavigationSelectors.is_paused(nav_slice), "Game should remain paused while pause overlay is active")


## MAIN MENU CONTEXT TESTS

func test_main_menu_settings_panel_returns_to_main() -> void:
	# Setup: main menu with settings panel active
	_store.dispatch(U_NavigationActions.set_menu_panel(StringName("menu/settings")))
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: back to main panel
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var active_panel: StringName = nav_slice.get("active_menu_panel", StringName())
	assert_eq(active_panel, StringName("menu/main"), "Should return to main panel from settings panel")


func test_main_menu_root_panel_no_op() -> void:
	# Setup: main menu at root panel (default)
	var nav_slice_before: Dictionary = _store.get_slice(StringName("navigation"))
	var panel_before: StringName = nav_slice_before.get("active_menu_panel", StringName())

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: no state change (no-op)
	var nav_slice_after: Dictionary = _store.get_slice(StringName("navigation"))
	var panel_after: StringName = nav_slice_after.get("active_menu_panel", StringName())
	assert_eq(panel_after, panel_before, "Should be no-op at main menu root panel")
	assert_eq(panel_after, StringName("menu/main"), "Should still be at menu/main")


## ENDGAME CONTEXT TESTS

func test_game_over_triggers_retry() -> void:
	# Setup: endgame shell, game_over scene
	_store.dispatch(U_NavigationActions.open_endgame(StringName("game_over")))
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: dispatched retry action (shell → gameplay)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var shell: StringName = nav_slice.get("shell", StringName())
	assert_eq(shell, StringName("gameplay"), "Should retry to gameplay shell from game_over")


func test_victory_skips_to_credits() -> void:
	# Setup: endgame shell, victory scene
	_store.dispatch(U_NavigationActions.open_endgame(StringName("victory")))
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: dispatched skip_to_credits (base_scene_id → credits)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var base_scene_id: StringName = nav_slice.get("base_scene_id", StringName())
	assert_eq(base_scene_id, StringName("credits"), "Should skip to credits from victory")


func test_credits_returns_to_main_menu() -> void:
	# Setup: endgame shell, credits scene
	_store.dispatch(U_NavigationActions.open_endgame(StringName("victory")))
	_store.dispatch(U_NavigationActions.skip_to_credits())
	await wait_process_frames(2)

	# Action: press ui_cancel
	_simulate_ui_cancel()
	await wait_process_frames(2)

	# Assert: dispatched skip_to_menu (shell → main_menu)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var shell: StringName = nav_slice.get("shell", StringName())
	assert_eq(shell, StringName("main_menu"), "Should return to main menu from credits")


## UI_PAUSE IDENTICAL TO UI_CANCEL

func test_ui_pause_identical_to_ui_cancel() -> void:
	# Setup: gameplay shell, no overlays
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await wait_process_frames(2)

	# Action: press ui_pause instead of ui_cancel
	_simulate_ui_pause()
	await wait_process_frames(2)

	# Assert: same behavior as ui_cancel (opens pause)
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 1, "ui_pause should behave identically to ui_cancel")
	assert_eq(overlay_stack[0], StringName("pause_menu"), "Should open pause menu")


func test_ui_pause_is_ignored_when_scene_manager_suppresses_current_frame() -> void:
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await wait_process_frames(2)

	_scene_manager_stub.suppress_pause = true

	_simulate_ui_pause()
	await wait_process_frames(2)

	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(overlay_stack.size(), 0, "ui_pause should be ignored while current-frame suppression is active")


## HELPER FUNCTIONS

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	U_ServiceLocator.register(StringName("state_store"), store)
	await wait_process_frames(2)
	return store


func _create_input_handler() -> M_UIInputHandler:
	var handler := M_UIInputHandler.new()
	add_child_autofree(handler)
	await wait_process_frames(1)
	return handler


func _simulate_ui_cancel() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	_input_handler._unhandled_input(event)


func _simulate_ui_pause() -> void:
	var event := InputEventAction.new()
	event.action = "ui_pause"
	event.pressed = true
	_input_handler._unhandled_input(event)
