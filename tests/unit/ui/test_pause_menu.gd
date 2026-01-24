extends GutTest

const PauseMenuScene := preload("res://scenes/ui/ui_pause_menu.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")

func test_resume_button_closes_pause_overlay() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	resume_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	assert_true(nav_slice.get("overlay_stack", []).is_empty(),
		"Resume button should clear overlay stack")

func test_settings_button_opens_settings_overlay() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var settings_button: Button = pause_menu.get_node("%SettingsButton")
	settings_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	var stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(stack.back(), StringName("settings_menu_overlay"),
		"Settings button should push the settings overlay")

func test_quit_button_returns_to_main_menu() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var quit_button: Button = pause_menu.get_node("%QuitButton")
	quit_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("main_menu"),
		"Quit should return to main menu shell")
	assert_eq(nav_slice.get("base_scene_id"), StringName("main_menu"),
		"Quit should target main_menu scene")

func test_back_action_matches_resume() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	pause_menu._unhandled_input(event)
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	assert_true(nav_slice.get("overlay_stack", []).is_empty(),
		"ui_cancel should close pause overlay via navigation action")

func test_pause_menu_hidden_when_transitioning_to_main_menu() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	# Pause menu should be visible during gameplay pause
	assert_true(pause_menu.visible, "Pause menu should be visible when paused in gameplay")

	# Simulate clicking "Quit to Main Menu" - this clears overlays AND changes shell
	store.dispatch(U_NavigationActions.return_to_main_menu())
	await wait_physics_frames(2)

	# Pause menu should be hidden because we're transitioning to main menu shell
	assert_false(pause_menu.visible, "Pause menu should be hidden when transitioning to main menu")

func test_switching_to_gamepad_focuses_resume_button() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, 0, 0.0))
	await wait_process_frames(2)

	var viewport := pause_menu.get_viewport()
	var focused := viewport.gui_get_focus_owner()
	assert_not_null(focused, "Pause menu should have a focused control after switching to gamepad")
	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	assert_eq(focused, resume_button, "Resume button should be focused after switching to gamepad")

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
	await wait_process_frames(2)
	return store

func _prepare_paused_state(store: M_StateStore) -> void:
	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	store.dispatch(U_NavigationActions.open_pause())

func _instantiate_pause_menu() -> Control:
	var pause_menu := PauseMenuScene.instantiate()
	add_child_autofree(pause_menu)
	await wait_process_frames(2)
	return pause_menu
