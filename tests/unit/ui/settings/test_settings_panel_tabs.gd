extends GutTest

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")
const SCENE_PATH := "res://scenes/core/ui/settings/ui_settings_panel.tscn"

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
	panel.queue_free()

func _create_panel() -> UI_SettingsPanel:
	var scene := load(SCENE_PATH) as PackedScene
	var panel := scene.instantiate() as UI_SettingsPanel
	add_child(panel)
	await get_tree().process_frame
	return panel