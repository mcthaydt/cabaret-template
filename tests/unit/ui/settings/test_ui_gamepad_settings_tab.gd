extends GutTest

const UI_GamepadSettingsTab := preload("res://scripts/core/ui/settings/ui_gamepad_settings_tab.gd")

func test_gamepad_settings_tab_extends_vboxcontainer():
	var tab := UI_GamepadSettingsTab.new()
	assert_true(tab is VBoxContainer, "Gamepad settings tab should extend VBoxContainer")
	tab.free()