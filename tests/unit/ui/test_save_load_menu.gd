extends GutTest

const SaveLoadMenuScene := preload("res://scenes/ui/overlays/ui_save_load_menu.tscn")
const U_SAVE_TEST_UTILS := preload("res://tests/unit/save/u_save_test_utils.gd")

const PLACEHOLDER_TEXTURE_PATH := "res://resources/ui/tex_save_slot_placeholder.png"
const TEST_THUMB_DIR := "user://test_ui_thumbs/"

var _test_save_manager: MockSaveManager
var _test_store: M_StateStore

func before_each() -> void:
	U_ServiceLocator.clear()
	# Create and register mock save manager first
	_test_save_manager = MockSaveManager.new()
	add_child_autofree(_test_save_manager)
	U_ServiceLocator.register(StringName("save_manager"), _test_save_manager)
	await wait_process_frames(2)

	# Create state store
	_test_store = await _create_state_store()
	U_SAVE_TEST_UTILS.setup(TEST_THUMB_DIR)

func after_each() -> void:
	# Note: _test_save_manager and _test_store are freed by add_child_autofree()
	U_SAVE_TEST_UTILS.teardown(TEST_THUMB_DIR)
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

func test_slot_item_includes_thumbnail_texture_rect() -> void:
	_prepare_save_mode(_test_store)
	_test_save_manager.set_slot_metadata([
		_build_slot_metadata(StringName("slot_01"), true, "")
	])
	var menu := await _instantiate_save_load_menu()

	var slot_container := _get_slot_container(menu, StringName("slot_01"))
	assert_not_null(slot_container, "Slot container should exist for slot_01")

	var thumbnail_rect := _find_thumbnail_rect(slot_container)
	assert_not_null(thumbnail_rect, "Slot item should include a thumbnail TextureRect")

func test_placeholder_shown_when_thumbnail_path_empty() -> void:
	_prepare_save_mode(_test_store)
	_test_save_manager.set_slot_metadata([
		_build_slot_metadata(StringName("slot_01"), true, "")
	])
	var menu := await _instantiate_save_load_menu()
	await wait_process_frames(2)

	var slot_container := _get_slot_container(menu, StringName("slot_01"))
	var thumbnail_rect := _find_thumbnail_rect(slot_container)
	assert_not_null(thumbnail_rect, "Thumbnail TextureRect should exist for slot_01")
	if thumbnail_rect == null:
		return
	assert_not_null(thumbnail_rect.texture, "Placeholder texture should be assigned when thumbnail_path is empty")
	if thumbnail_rect.texture == null:
		return
	assert_eq(
		thumbnail_rect.texture.resource_path,
		PLACEHOLDER_TEXTURE_PATH,
		"Placeholder texture should be used when thumbnail_path is empty"
	)

func test_placeholder_shown_when_thumbnail_file_missing() -> void:
	_prepare_save_mode(_test_store)
	var missing_path := TEST_THUMB_DIR + "slot_01_thumb.png"
	_test_save_manager.set_slot_metadata([
		_build_slot_metadata(StringName("slot_01"), true, missing_path)
	])
	var menu := await _instantiate_save_load_menu()
	await wait_process_frames(2)

	var slot_container := _get_slot_container(menu, StringName("slot_01"))
	var thumbnail_rect := _find_thumbnail_rect(slot_container)
	assert_not_null(thumbnail_rect, "Thumbnail TextureRect should exist for slot_01")
	if thumbnail_rect == null:
		return
	assert_not_null(thumbnail_rect.texture, "Placeholder texture should be shown when thumbnail file is missing")
	if thumbnail_rect.texture == null:
		return
	assert_eq(
		thumbnail_rect.texture.resource_path,
		PLACEHOLDER_TEXTURE_PATH,
		"Placeholder texture should be used when thumbnail file is missing"
	)

func test_thumbnail_displayed_when_file_exists() -> void:
	_prepare_save_mode(_test_store)
	var thumbnail_path := TEST_THUMB_DIR + "slot_01_thumb.png"
	_create_test_thumbnail(thumbnail_path)
	_test_save_manager.set_slot_metadata([
		_build_slot_metadata(StringName("slot_01"), true, thumbnail_path)
	])
	var menu := await _instantiate_save_load_menu()

	var slot_container := _get_slot_container(menu, StringName("slot_01"))
	var thumbnail_rect := _find_thumbnail_rect(slot_container)
	assert_not_null(thumbnail_rect, "Thumbnail TextureRect should exist for slot_01")
	if thumbnail_rect == null:
		return
	await _await_texture_path(thumbnail_rect, thumbnail_path)

	assert_not_null(thumbnail_rect.texture, "Thumbnail texture should load when file exists")
	assert_ne(
		thumbnail_rect.texture.resource_path,
		PLACEHOLDER_TEXTURE_PATH,
		"Thumbnail TextureRect should not use placeholder when file exists"
	)
	if not thumbnail_rect.texture.resource_path.is_empty():
		assert_eq(
			thumbnail_rect.texture.resource_path,
			thumbnail_path,
			"Thumbnail TextureRect should load the file-based thumbnail"
		)

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
	# Ensure save manager is resolved and slot list is populated for assertions.
	if menu.get("_save_manager") == null:
		menu.call("_discover_save_manager")
	menu.call("_refresh_slot_list")
	await wait_process_frames(2)
	await _wait_for_slot_list(menu)
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
		store.dispatch(U_NavigationActions.set_shell(StringName("gameplay"), StringName("alleyway")))
		store.dispatch(U_NavigationActions.open_pause())
		store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))
		await wait_process_frames(2)

func _build_slot_metadata(slot_id: StringName, exists: bool, thumbnail_path: String) -> Dictionary:
	return {
		"slot_id": slot_id,
		"exists": exists,
		"timestamp": "2025-12-26T10:00:00Z",
		"area_name": "Test Area",
		"playtime_seconds": 123,
		"thumbnail_path": thumbnail_path
	}

func _get_slot_container(menu: Control, slot_id: StringName) -> HBoxContainer:
	if menu == null:
		return null
	var list_container := menu.get_node_or_null("%SlotListContainer")
	if list_container == null:
		return null
	return list_container.get_node_or_null("Slot_" + String(slot_id)) as HBoxContainer

func _find_thumbnail_rect(container: Node) -> TextureRect:
	if container == null:
		return null
	if container is TextureRect:
		return container
	for child in container.get_children():
		var found := _find_thumbnail_rect(child)
		if found != null:
			return found
	return null

func _wait_for_slot_list(menu: Control, max_frames: int = 10) -> void:
	if menu == null:
		return
	for _i in max_frames:
		var list_container := menu.get_node_or_null("%SlotListContainer")
		if list_container != null and list_container.get_child_count() > 0:
			return
		await wait_process_frames(1)

func _create_test_thumbnail(path: String) -> void:
	var image := Image.create(32, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0, 0, 1))
	image.save_png(path)

func _await_texture_path(texture_rect: TextureRect, expected_path: String, max_frames: int = 30) -> void:
	if texture_rect == null:
		return
	for _i in max_frames:
		if texture_rect.texture != null and texture_rect.texture.resource_path == expected_path:
			return
		await wait_process_frames(1)
