extends GutTest

const UI_PAUSE_MENU_SCRIPT := preload("res://scripts/core/ui/menus/ui_pause_menu.gd")

func test_pause_menu_overlay_settings_is_settings_panel() -> void:
	assert_eq(UI_PauseMenu.OVERLAY_SETTINGS, StringName("settings_panel"), "OVERLAY_SETTINGS should point to settings_panel")