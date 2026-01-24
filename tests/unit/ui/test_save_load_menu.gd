extends GutTest

const SaveLoadMenuScene := preload("res://scenes/ui/ui_save_load_menu.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const MockSaveManager := preload("res://tests/mocks/mock_save_manager.gd")

var _test_save_manager: Node
var _test_store: M_StateStore

func before_each() -> void:
	U_ServiceLocator.clear()
	# Create and register mock save manager first
	_test_save_manager = MockSaveManager.new()
	add_child_autofree(_test_save_manager)
	await wait_process_frames(2)

	# Create state store
	_test_store = await _create_state_store()

func after_each() -> void:
	# Note: _test_save_manager and _test_store are freed by add_child_autofree()
	U_ServiceLocator.clear()

func test_spinner_hidden_initially() -> void:
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	var spinner := menu.get_node_or_null("%LoadingSpinner") as Control
	assert_not_null(spinner, "LoadingSpinner should exist in scene")
	assert_false(spinner.visible, "LoadingSpinner should be hidden initially")

func test_spinner_shows_during_load() -> void:
	_prepare_load_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Simulate loading a slot (mock will delay completion)
	_test_save_manager.set_delayed_load(true, 0.5)  # 0.5 second delay

	# Trigger load
	menu._perform_load(StringName("slot_01"))
	await wait_process_frames(2)

	var spinner := menu.get_node("%LoadingSpinner") as Control
	assert_true(spinner.visible, "LoadingSpinner should be visible during load")

func test_spinner_hides_after_load_completes() -> void:
	_prepare_load_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Simulate loading a slot with short delay
	_test_save_manager.set_delayed_load(true, 0.1)

	# Trigger load
	menu._perform_load(StringName("slot_01"))
	await wait_process_frames(2)

	# Spinner should be visible during load
	var spinner := menu.get_node("%LoadingSpinner") as Control
	assert_true(spinner.visible, "LoadingSpinner should be visible during load")

	# Wait for load to complete
	await wait_seconds(0.2)

	# Spinner should be hidden after load completes
	assert_false(spinner.visible, "LoadingSpinner should be hidden after load completes")

func test_buttons_disabled_during_load() -> void:
	_prepare_load_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Simulate loading with delay
	_test_save_manager.set_delayed_load(true, 0.5)

	# Trigger load
	menu._perform_load(StringName("slot_01"))
	await wait_process_frames(2)

	# All buttons should be disabled during load
	var back_button := menu.get_node("%BackButton") as Button
	assert_true(back_button.disabled, "Back button should be disabled during load")

	# Check slot list buttons are also disabled
	var slot_container := menu.get_node("%SlotListContainer")
	for child in slot_container.get_children():
		if child is HBoxContainer:
			var main_button := child.get_node_or_null("MainButton") as Button
			if main_button:
				assert_true(main_button.disabled, "Slot buttons should be disabled during load")

func test_buttons_enabled_after_load_completes() -> void:
	_prepare_load_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get back button reference before load
	var back_button := menu.get_node("%BackButton") as Button
	var initial_disabled := back_button.disabled

	# Simulate loading with short delay
	_test_save_manager.set_delayed_load(true, 0.1)

	# Trigger load
	menu._perform_load(StringName("slot_01"))
	await wait_process_frames(2)

	# Wait for load to complete
	await wait_seconds(0.2)

	# Back button should return to original state
	assert_eq(back_button.disabled, initial_disabled, "Back button should return to original state after load")

func test_save_failure_shows_error_message() -> void:
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	_test_save_manager.set_next_save_result(ERR_FILE_CANT_WRITE)
	menu._perform_save(StringName("slot_01"))
	await wait_process_frames(2)

	var error_label := menu.get_node_or_null("%ErrorLabel") as Label
	assert_not_null(error_label, "ErrorLabel should exist in scene")
	assert_true(error_label.visible, "ErrorLabel should be visible after save failure")
	assert_ne(error_label.text.strip_edges(), "", "ErrorLabel text should not be empty after save failure")

func test_delete_failure_shows_error_message() -> void:
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	_test_save_manager.set_next_delete_result(ERR_FILE_CANT_OPEN)
	menu._perform_delete(StringName("slot_01"))
	await wait_process_frames(2)

	var error_label := menu.get_node_or_null("%ErrorLabel") as Label
	assert_not_null(error_label, "ErrorLabel should exist in scene")
	assert_true(error_label.visible, "ErrorLabel should be visible after delete failure")
	assert_ne(error_label.text.strip_edges(), "", "ErrorLabel text should not be empty after delete failure")

func test_load_failure_keeps_overlay_open_and_shows_error_message() -> void:
	_prepare_load_mode(_test_store)
	await _open_save_load_overlay_in_gameplay(_test_store)
	var menu := await _instantiate_save_load_menu()

	var nav_state: Dictionary = _test_store.get_state().get("navigation", {})
	var overlay_stack: Array = nav_state.get("overlay_stack", [])
	assert_eq(
		overlay_stack,
		[StringName("save_load_menu_overlay")],
		"Save/load overlay should be on stack before load"
	)

	_test_save_manager.set_next_load_result(ERR_FILE_NOT_FOUND)
	menu._perform_load(StringName("slot_01"))
	await wait_process_frames(2)

	nav_state = _test_store.get_state().get("navigation", {})
	overlay_stack = nav_state.get("overlay_stack", [])
	assert_eq(
		overlay_stack,
		[StringName("save_load_menu_overlay")],
		"Save/load overlay should remain on stack after immediate load failure"
	)

	var error_label := menu.get_node_or_null("%ErrorLabel") as Label
	assert_not_null(error_label, "ErrorLabel should exist in scene")
	assert_true(error_label.visible, "ErrorLabel should be visible after load failure")
	assert_ne(error_label.text.strip_edges(), "", "ErrorLabel text should not be empty after load failure")

## Helper functions

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _instantiate_save_load_menu() -> Control:
	var menu := SaveLoadMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(2)
	return menu

func _prepare_save_mode(store: M_StateStore) -> void:
	if store != null:
		store.dispatch(U_NavigationActions.set_save_load_mode(StringName("save")))
		await wait_process_frames(2)

func _prepare_load_mode(store: M_StateStore) -> void:
	if store != null:
		store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
		await wait_process_frames(2)

func _open_save_load_overlay_in_gameplay(store: M_StateStore) -> void:
	if store != null:
		store.dispatch(U_NavigationActions.set_shell(StringName("gameplay"), StringName("exterior")))
		store.dispatch(U_NavigationActions.open_pause())
		store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))
		await wait_process_frames(2)
