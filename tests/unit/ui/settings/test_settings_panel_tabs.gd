extends "res://tests/base_test.gd"

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")
const SCENE_PATH := "res://scenes/core/ui/settings/ui_settings_panel.tscn"
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/core/managers/m_input_device_manager.gd")

var _store: M_StateStore = null

func before_each() -> void:
	super.before_each()
	_store = _create_state_store()

func after_each() -> void:
	_store = null
	super.after_each()

func test_settings_panel_has_tab_bar():
	var panel := await _create_panel()
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	assert_not_null(tab_bar, "Settings panel should have a TabBar HBoxContainer")
	panel.queue_free()

func test_settings_panel_has_content_container():
	var panel := await _create_panel()
	var content := panel.find_child("ContentContainer", true, false) as VBoxContainer
	assert_not_null(content, "Settings panel should have a ContentContainer VBoxContainer")
	panel.queue_free()

func test_settings_panel_default_tab_is_display():
	var panel := await _create_panel()
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_DISPLAY, "Default active tab should be Display")
	var display_content := panel._tab_contents.get(UI_SettingsPanel.TAB_DISPLAY) as Control
	assert_not_null(display_content, "Display tab content should exist")
	assert_true(display_content.visible, "Display tab content should be visible by default")
	panel.queue_free()

func test_switch_tab_updates_active_id():
	var panel := await _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_AUDIO, "Active tab should be Audio after switch")
	panel.queue_free()

func test_switch_tab_shows_content_hides_others():
	var panel := await _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	await get_tree().process_frame
	var audio_content := panel._tab_contents.get(UI_SettingsPanel.TAB_AUDIO) as Control
	var display_content := panel._tab_contents.get(UI_SettingsPanel.TAB_DISPLAY) as Control
	assert_not_null(audio_content, "Audio tab content should exist")
	assert_not_null(display_content, "Display tab content should exist")
	assert_true(audio_content.visible, "Audio content should be visible when active")
	assert_false(display_content.visible, "Display content should be hidden when inactive")
	panel.queue_free()

func _create_panel() -> UI_SettingsPanel:
	var scene := load(SCENE_PATH) as PackedScene
	var panel := scene.instantiate() as UI_SettingsPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	store.settings = test_settings
	store.audio_initial_state = RS_AudioInitialState.new()
	store.display_initial_state = RS_DisplayInitialState.new()
	store.localization_initial_state = RS_LocalizationInitialState.new()
	store.vfx_initial_state = RS_VFXInitialState.new()
	add_child_autofree(store)
	U_ServiceLocator.register(StringName("state_store"), store)
	return store
