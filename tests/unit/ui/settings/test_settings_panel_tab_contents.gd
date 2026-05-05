extends GutTest

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_BOOT_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_boot_initial_state.gd")
const RS_MENU_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_menu_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")

var _store: M_StateStore = null

func before_each() -> void:
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING

func after_each() -> void:
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.FAILURE
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.FAILURE

func test_panel_creates_all_tab_contents():
	var panel := await _create_panel()
	var expected_ids := [
		UI_SettingsPanel.TAB_DISPLAY,
		UI_SettingsPanel.TAB_AUDIO,
		UI_SettingsPanel.TAB_VFX,
		UI_SettingsPanel.TAB_LANGUAGE,
		UI_SettingsPanel.TAB_GAMEPAD,
		UI_SettingsPanel.TAB_KEYBOARD_MOUSE,
		UI_SettingsPanel.TAB_TOUCHSCREEN,
	]
	for tab_id in expected_ids:
		var content := panel._tab_contents.get(tab_id) as Control
		assert_not_null(content, "Should have content for tab " + str(tab_id))
	panel.queue_free()
	await _cleanup()

func test_tab_contents_have_correct_names():
	var panel := await _create_panel()
	var expected_names := {
		UI_SettingsPanel.TAB_DISPLAY: "DisplayTabContent",
		UI_SettingsPanel.TAB_AUDIO: "AudioTabContent",
		UI_SettingsPanel.TAB_VFX: "VFXTabContent",
		UI_SettingsPanel.TAB_LANGUAGE: "LanguageTabContent",
		UI_SettingsPanel.TAB_GAMEPAD: "GamepadTabContent",
		UI_SettingsPanel.TAB_KEYBOARD_MOUSE: "KeyboardMouseTabContent",
		UI_SettingsPanel.TAB_TOUCHSCREEN: "TouchscreenTabContent",
	}
	for tab_id in expected_names:
		var content: Control = panel._tab_contents[tab_id]
		assert_eq(content.name, expected_names[tab_id], "Tab content name should match: " + str(tab_id))
	panel.queue_free()
	await _cleanup()

func test_tab_contents_are_children_of_content_container():
	var panel := await _create_panel()
	for tab_id in panel._tab_contents:
		var content: Control = panel._tab_contents[tab_id]
		assert_eq(content.get_parent(), panel._content_container, "Tab content should be child of ContentContainer: " + str(tab_id))
	panel.queue_free()
	await _cleanup()

func test_tab_contents_expand_fill():
	var panel := await _create_panel()
	for tab_id in panel._tab_contents:
		var content: Control = panel._tab_contents[tab_id]
		assert_eq(content.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Tab content should expand-fill horizontally: " + str(tab_id))
		assert_eq(content.size_flags_vertical, Control.SIZE_EXPAND_FILL, "Tab content should expand-fill vertically: " + str(tab_id))
	panel.queue_free()
	await _cleanup()

func test_switch_to_tab_shows_target_content():
	var panel := await _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	var audio_content: Control = panel._tab_contents.get(UI_SettingsPanel.TAB_AUDIO)
	assert_not_null(audio_content, "Audio tab content should exist")
	if audio_content != null:
		assert_true(audio_content.visible, "Audio tab content should be visible after switching to it")
	panel.queue_free()
	await _cleanup()

func test_tab_content_count_matches_tab_ids():
	var panel := await _create_panel()
	assert_eq(panel._tab_contents.size(), 7, "Should have exactly 7 tab content entries")
	panel.queue_free()
	await _cleanup()

func _create_panel() -> UI_SettingsPanel:
	U_ServiceLocator.push_scope()
	_store = M_StateStore.new()
	_store.name = "M_StateStore"
	_store.settings = RS_STATE_STORE_SETTINGS.new()
	_store.settings.enable_persistence = false
	_store.boot_initial_state = RS_BOOT_INITIAL_STATE.new()
	_store.menu_initial_state = RS_MENU_INITIAL_STATE.new()
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	add_child(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := load("res://scenes/core/ui/settings/ui_settings_panel.tscn") as PackedScene
	var panel := scene.instantiate() as UI_SettingsPanel
	add_child(panel)
	await get_tree().process_frame
	return panel

func _cleanup() -> void:
	U_ServiceLocator.pop_scope()
	if _store != null and is_instance_valid(_store):
		_store.queue_free()
	_store = null
	await get_tree().process_frame
