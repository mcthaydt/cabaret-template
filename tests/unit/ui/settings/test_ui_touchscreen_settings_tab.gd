extends GutTest

const UI_TouchscreenSettingsTab := preload("res://scripts/core/ui/settings/ui_touchscreen_settings_tab.gd")

func test_touchscreen_settings_tab_extends_vboxcontainer():
	var tab := UI_TouchscreenSettingsTab.new()
	assert_true(tab is VBoxContainer, "Touchscreen settings tab should extend VBoxContainer")
	tab.free()