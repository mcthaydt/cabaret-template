extends GutTest

const UI_KeyboardMouseSettingsTab := preload("res://scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd")

func test_keyboard_mouse_settings_tab_extends_vboxcontainer():
	var tab := UI_KeyboardMouseSettingsTab.new()
	assert_true(tab is VBoxContainer, "K/M settings tab should extend VBoxContainer")
	tab.free()