extends GutTest

const SaveLoadMenuScene := preload("res://scenes/ui/ui_save_load_menu.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const MockSaveManager := preload("res://tests/mocks/mock_save_manager.gd")

var _test_save_manager: Node
var _test_store: M_StateStore

func before_each() -> void:
	# Create and register mock save manager first
	_test_save_manager = MockSaveManager.new()
	add_child_autofree(_test_save_manager)
	await wait_process_frames(2)

	# Manually register with ServiceLocator since it may not exist in test
	U_ServiceLocator.register(StringName("save_manager"), _test_save_manager)

	# Create state store
	_test_store = await _create_state_store()

func after_each() -> void:
	# Note: _test_save_manager and _test_store are freed by add_child_autofree()
	# ServiceLocator will automatically clean up invalid references
	pass

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

## Focus configuration tests

func test_horizontal_navigation_main_to_delete() -> void:
	# Setup: Create populated slots (mock will return exists=true)
	_test_save_manager.set_slot_exists(StringName("slot_01"), true)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get the first slot's buttons
	var slot_container := menu.get_node("%SlotListContainer")
	var first_slot := slot_container.get_child(1) as HBoxContainer  # Index 0 is autosave, 1 is slot_01
	assert_not_null(first_slot, "First manual slot should exist")

	var main_button := first_slot.get_node_or_null("MainButton") as Button
	var delete_button := first_slot.get_node_or_null("DeleteButton") as Button
	assert_not_null(main_button, "Main button should exist")
	assert_not_null(delete_button, "Delete button should exist")

	# Verify horizontal navigation is configured
	var right_neighbor_path := main_button.focus_neighbor_right
	assert_ne(right_neighbor_path, NodePath(), "Main button should have right neighbor configured")

	# Verify the right neighbor is the delete button
	var right_neighbor := main_button.get_node_or_null(right_neighbor_path) as Button
	assert_eq(right_neighbor, delete_button, "Main button's right neighbor should be delete button")

func test_horizontal_navigation_delete_to_main() -> void:
	# Setup: Create populated slot
	_test_save_manager.set_slot_exists(StringName("slot_01"), true)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get the first slot's buttons
	var slot_container := menu.get_node("%SlotListContainer")
	var first_slot := slot_container.get_child(1) as HBoxContainer
	var main_button := first_slot.get_node("MainButton") as Button
	var delete_button := first_slot.get_node("DeleteButton") as Button

	# Verify horizontal navigation is configured
	var left_neighbor_path := delete_button.focus_neighbor_left
	assert_ne(left_neighbor_path, NodePath(), "Delete button should have left neighbor configured")

	# Verify the left neighbor is the main button
	var left_neighbor := delete_button.get_node_or_null(left_neighbor_path) as Button
	assert_eq(left_neighbor, main_button, "Delete button's left neighbor should be main button")

func test_vertical_navigation_main_buttons() -> void:
	# Setup: Create two populated slots
	_test_save_manager.set_slot_exists(StringName("slot_01"), true)
	_test_save_manager.set_slot_exists(StringName("slot_02"), true)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get slot buttons
	var slot_container := menu.get_node("%SlotListContainer")
	var first_slot := slot_container.get_child(1) as HBoxContainer  # slot_01
	var second_slot := slot_container.get_child(2) as HBoxContainer  # slot_02

	var first_main := first_slot.get_node("MainButton") as Button
	var second_main := second_slot.get_node("MainButton") as Button

	# Verify vertical navigation from first to second
	var down_neighbor_path := first_main.focus_neighbor_bottom
	assert_ne(down_neighbor_path, NodePath(), "First main button should have bottom neighbor")

	var down_neighbor := first_main.get_node_or_null(down_neighbor_path) as Button
	assert_eq(down_neighbor, second_main, "First main button's bottom neighbor should be second main button")

func test_vertical_navigation_delete_buttons() -> void:
	# Setup: Create two populated slots
	_test_save_manager.set_slot_exists(StringName("slot_01"), true)
	_test_save_manager.set_slot_exists(StringName("slot_02"), true)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get slot buttons
	var slot_container := menu.get_node("%SlotListContainer")
	var first_slot := slot_container.get_child(1) as HBoxContainer  # slot_01
	var second_slot := slot_container.get_child(2) as HBoxContainer  # slot_02

	var first_delete := first_slot.get_node("DeleteButton") as Button
	var second_delete := second_slot.get_node("DeleteButton") as Button

	# Verify vertical navigation from first to second delete button
	var down_neighbor_path := first_delete.focus_neighbor_bottom
	assert_ne(down_neighbor_path, NodePath(), "First delete button should have bottom neighbor")

	var down_neighbor := first_delete.get_node_or_null(down_neighbor_path) as Button
	assert_eq(down_neighbor, second_delete, "First delete button's bottom neighbor should be second delete button")

func test_autosave_no_horizontal_navigation() -> void:
	# Setup: Autosave exists (delete button disabled)
	_test_save_manager.set_slot_exists(M_SaveManager.SLOT_AUTOSAVE, true)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get autosave slot (first child)
	var slot_container := menu.get_node("%SlotListContainer")
	var autosave_slot := slot_container.get_child(0) as HBoxContainer
	var main_button := autosave_slot.get_node("MainButton") as Button
	var delete_button := autosave_slot.get_node("DeleteButton") as Button

	# Verify delete button is disabled
	assert_true(delete_button.disabled, "Autosave delete button should be disabled")

	# Verify no horizontal navigation (right neighbor should be empty)
	var right_neighbor_path := main_button.focus_neighbor_right
	assert_eq(right_neighbor_path, NodePath(), "Autosave main button should have no right neighbor (delete disabled)")

func test_empty_slot_no_horizontal_navigation() -> void:
	# Setup: Empty slot (delete button not visible)
	_test_save_manager.set_slot_exists(StringName("slot_01"), false)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get the empty slot
	var slot_container := menu.get_node("%SlotListContainer")
	var empty_slot := slot_container.get_child(1) as HBoxContainer  # slot_01
	var main_button := empty_slot.get_node("MainButton") as Button
	var delete_button := empty_slot.get_node("DeleteButton") as Button

	# Verify delete button is not visible
	assert_false(delete_button.visible, "Empty slot delete button should not be visible")

	# Verify no horizontal navigation (right neighbor should be empty)
	var right_neighbor_path := main_button.focus_neighbor_right
	assert_eq(right_neighbor_path, NodePath(), "Empty slot main button should have no right neighbor (delete hidden)")

func test_back_button_connects_to_main_buttons() -> void:
	# Setup
	_test_save_manager.set_slot_exists(StringName("slot_01"), true)
	_prepare_save_mode(_test_store)
	var menu := await _instantiate_save_load_menu()

	# Get back button
	var back_button := menu.get_node("%BackButton") as Button
	var slot_container := menu.get_node("%SlotListContainer")

	# Get last slot's main button
	var last_slot := slot_container.get_child(slot_container.get_child_count() - 1) as HBoxContainer
	var last_main_button := last_slot.get_node("MainButton") as Button

	# Verify last main button → down → back button
	var last_down_path := last_main_button.focus_neighbor_bottom
	assert_ne(last_down_path, NodePath(), "Last main button should have bottom neighbor")
	var down_neighbor := last_main_button.get_node_or_null(last_down_path) as Button
	assert_eq(down_neighbor, back_button, "Last main button's bottom neighbor should be back button")

	# Verify back button → up → last main button
	var back_up_path := back_button.focus_neighbor_top
	assert_ne(back_up_path, NodePath(), "Back button should have top neighbor")
	var up_neighbor := back_button.get_node_or_null(back_up_path) as Button
	assert_eq(up_neighbor, last_main_button, "Back button's top neighbor should be last main button")
