extends GutTest

const U_UI_REGISTRY := preload("res://scripts/core/ui/utils/u_ui_registry.gd")

func test_settings_panel_registered_as_overlay() -> void:
	var screen: Dictionary = U_UI_REGISTRY.get_screen(StringName("settings_panel"))
	assert_ne(screen, {}, "settings_panel should be registered in U_UIRegistry")
	assert_eq(screen.get("kind"), 1, "settings_panel should be kind OVERLAY (1)")

func test_settings_panel_allowed_shells() -> void:
	var screen: Dictionary = U_UI_REGISTRY.get_screen(StringName("settings_panel"))
	assert_true(screen.get("allowed_shells", []).has(StringName("gameplay")), "settings_panel should allow gameplay shell")

func test_settings_panel_allowed_parents() -> void:
	var screen: Dictionary = U_UI_REGISTRY.get_screen(StringName("settings_panel"))
	assert_true(screen.get("allowed_parents", []).has(StringName("pause_menu")), "settings_panel should allow pause_menu as parent")