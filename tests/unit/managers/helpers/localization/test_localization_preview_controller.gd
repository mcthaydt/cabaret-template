extends GutTest

const U_LOCALIZATION_PREVIEW_CONTROLLER := preload("res://scripts/managers/helpers/localization/u_localization_preview_controller.gd")

func test_start_preview_applies_temporary_effective_settings() -> void:
	var controller := U_LOCALIZATION_PREVIEW_CONTROLLER.new()
	controller.start_preview({
		"locale": &"es",
		"dyslexia_font_enabled": true,
		"ui_scale_override": 1.25,
	})

	assert_true(controller.is_preview_active(), "Preview should be active after start_preview")
	assert_eq(controller.resolve_locale(&"en"), &"es", "Preview locale should override fallback locale")
	assert_true(controller.resolve_dyslexia_enabled(false), "Preview dyslexia value should override fallback")
	assert_eq(controller.get_effective_ui_scale(1.0), 1.25, "Preview UI scale should override store value")

func test_clear_preview_restores_store_driven_fallbacks() -> void:
	var controller := U_LOCALIZATION_PREVIEW_CONTROLLER.new()
	controller.start_preview({
		"locale": &"ja",
		"dyslexia_font_enabled": true,
		"ui_scale_override": 1.1,
	})

	assert_true(controller.clear_preview(), "clear_preview should return true when preview was active")
	assert_false(controller.is_preview_active(), "Preview should be inactive after clear")
	assert_eq(controller.resolve_locale(&"en"), &"en", "Locale should fall back to store value after clear")
	assert_false(controller.resolve_dyslexia_enabled(false), "Dyslexia should fall back to store value after clear")
	assert_eq(controller.get_effective_ui_scale(1.0), 1.0, "UI scale should fall back to store value after clear")

func test_store_updates_should_be_ignored_only_while_preview_active() -> void:
	var controller := U_LOCALIZATION_PREVIEW_CONTROLLER.new()
	assert_false(controller.should_ignore_store_updates(), "Store updates should not be ignored by default")

	controller.start_preview({"locale": &"pt"})
	assert_true(controller.should_ignore_store_updates(), "Store updates should be ignored while preview is active")

	controller.clear_preview()
	assert_false(controller.should_ignore_store_updates(), "Store updates should be processed again after clear")

func test_preview_settings_returns_deep_copy() -> void:
	var controller := U_LOCALIZATION_PREVIEW_CONTROLLER.new()
	controller.start_preview({"ui_scale_override": 1.5})

	var preview: Dictionary = controller.get_preview_settings()
	preview["ui_scale_override"] = 0.5

	assert_eq(controller.get_effective_ui_scale(1.0), 1.5, "Returned preview settings should not alias internal state")
