extends GutTest

const UI_VFXSettingsTab := preload("res://scripts/core/ui/settings/ui_vfx_settings_tab.gd")

func test_vfx_settings_tab_extends_vboxcontainer():
	var tab := UI_VFXSettingsTab.new()
	assert_true(tab is VBoxContainer, "VFX settings tab should extend VBoxContainer")
	tab.free()