extends GutTest

const BasePanel := preload("res://scripts/ui/base/base_panel.gd")
const BaseOverlay := preload("res://scripts/ui/base/base_overlay.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const OverlayStub := preload("res://tests/test_doubles/ui/overlay_stub.gd")

func test_base_panel_focuses_first_focusable_child() -> void:
	var store := await _create_state_store()
	assert_not_null(store, "State store should be available for BasePanel tests")

	var panel := BasePanel.new()
	var unfocusable_button := Button.new()
	unfocusable_button.focus_mode = Control.FOCUS_NONE
	panel.add_child(unfocusable_button)

	var focus_button := Button.new()
	focus_button.name = "SecondButton"
	focus_button.focus_mode = Control.FOCUS_ALL
	panel.add_child(focus_button)

	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_true(focus_button.has_focus(),
		"BasePanel should automatically focus the first focusable descendant control")

func test_base_overlay_handles_ui_cancel_back_action() -> void:
	await _create_state_store()
	var overlay := OverlayStub.new()
	var button := Button.new()
	overlay.add_child(button)
	add_child_autofree(overlay)
	await wait_process_frames(3)

	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS,
		"BaseOverlay should process even when the tree is paused")

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	overlay._unhandled_input(cancel_event)

	assert_true(overlay.back_pressed,
		"BaseOverlay should call _on_back_pressed() when ui_cancel is pressed")

func test_base_panel_exposes_state_store_reference() -> void:
	var store := await _create_state_store()
	var panel := BasePanel.new()
	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_true(panel.get_store() is M_StateStore,
		"BasePanel should store an M_StateStore reference after ready")
	assert_eq(panel.get_store(), store,
		"BasePanel should resolve the same store instance in the scene tree")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store
