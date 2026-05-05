extends GutTest

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/core/managers/m_input_device_manager.gd")

func test_display_tab_always_visible():
	var panel := await _create_panel()
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_DISPLAY)
	if btn != null:
		assert_true(btn.visible, "Display tab should always be visible")
	panel.queue_free()

func test_audio_tab_always_visible():
	var panel := await _create_panel()
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_AUDIO)
	if btn != null:
		assert_true(btn.visible, "Audio tab should always be visible")
	panel.queue_free()

func test_vfx_tab_always_visible():
	var panel := await _create_panel()
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_VFX)
	if btn != null:
		assert_true(btn.visible, "VFX tab should always be visible")
	panel.queue_free()

func test_language_tab_always_visible():
	var panel := await _create_panel()
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_LANGUAGE)
	if btn != null:
		assert_true(btn.visible, "Language tab should always be visible")
	panel.queue_free()

func test_keyboard_mouse_tab_hidden_in_mobile_context():
	var panel := await _create_panel()
	panel.emulate_mobile_override = true
	panel._update_tab_visibility()
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_KEYBOARD_MOUSE)
	if btn != null:
		assert_false(btn.visible, "K/M tab should be hidden when emulate_mobile_override is true")
	panel.queue_free()

func test_gamepad_tab_hidden_without_gamepad():
	var panel := await _create_panel()
	panel._update_tab_visibility({"input": {"gamepad_connected": false, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.KEYBOARD_MOUSE}})
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_GAMEPAD)
	if btn != null:
		assert_false(btn.visible, "Gamepad tab should be hidden when no gamepad connected")
	panel.queue_free()

func test_touchscreen_tab_hidden_outside_mobile_context():
	var panel := await _create_panel()
	panel.emulate_mobile_override = false
	panel._update_tab_visibility({"input": {"gamepad_connected": false, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.KEYBOARD_MOUSE}})
	var btn: Button = _get_tab_button(panel, UI_SettingsPanel.TAB_TOUCHSCREEN)
	if btn != null:
		assert_false(btn.visible, "Touchscreen tab should be hidden outside mobile context")
	panel.queue_free()

func test_active_tab_snaps_when_hidden():
	var panel := await _create_panel()
	panel.emulate_mobile_override = true
	panel._update_tab_visibility()
	assert_ne(panel.get_active_tab_id(), -1, "Should have a valid active tab after visibility update")
	panel.queue_free()

func test_snap_to_first_visible_tab():
	var panel := await _create_panel()
	panel.emulate_mobile_override = true
	panel._update_tab_visibility()
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_DISPLAY, "Should snap to Display (first always-visible tab)")
	panel.queue_free()

func test_is_mobile_context_with_override():
	var panel := await _create_panel()
	panel.emulate_mobile_override = true
	assert_true(panel._is_mobile_context(), "_is_mobile_context should return true when emulate_mobile_override is true")
	panel.queue_free()

func test_is_tab_hidden_returns_true_for_invisible():
	var panel := await _create_panel()
	panel.emulate_mobile_override = true
	panel._update_tab_visibility()
	assert_true(panel._is_tab_hidden(UI_SettingsPanel.TAB_KEYBOARD_MOUSE), "_is_tab_hidden should return true for hidden tab")
	panel.queue_free()

func test_is_tab_hidden_returns_false_for_visible():
	var panel := await _create_panel()
	assert_false(panel._is_tab_hidden(UI_SettingsPanel.TAB_DISPLAY), "_is_tab_hidden should return false for visible tab")
	panel.queue_free()

func test_device_type_change_touchscreen_to_gamepad_resets_nav():
	var panel := await _create_panel()
	panel._last_device_type = M_INPUT_DEVICE_MANAGER.DeviceType.TOUCHSCREEN
	panel._update_tab_visibility({"input": {"gamepad_connected": true, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.GAMEPAD}})
	assert_true(panel._consume_next_nav, "_consume_next_nav should be true after TOUCHSCREEN→GAMEPAD transition")
	panel.queue_free()

func test_navigate_focus_consumes_next_nav():
	var panel := await _create_panel()
	panel._consume_next_nav = true
	panel._navigate_focus(&"ui_right")
	assert_false(panel._consume_next_nav, "_consume_next_nav should be false after consuming")
	panel.queue_free()

func _create_panel() -> UI_SettingsPanel:
	var scene := load("res://scenes/core/ui/settings/ui_settings_panel.tscn") as PackedScene
	var panel := scene.instantiate() as UI_SettingsPanel
	add_child(panel)
	await get_tree().process_frame
	return panel

func _get_tab_button(panel: UI_SettingsPanel, tab_id: int) -> Button:
	var data: Dictionary = panel._tab_buttons.get(tab_id, {})
	return data.get("button") as Button