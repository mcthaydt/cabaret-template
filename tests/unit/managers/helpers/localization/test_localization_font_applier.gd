extends GutTest

const U_LOCALIZATION_FONT_APPLIER := preload("res://scripts/managers/helpers/localization/u_localization_font_applier.gd")

func test_build_theme_prefers_cjk_font_over_dyslexia_toggle() -> void:
	var default_font := FontFile.new()
	var dyslexia_font := FontFile.new()
	var cjk_font := FontFile.new()
	var applier := U_LOCALIZATION_FONT_APPLIER.new()
	applier.set_fonts(default_font, dyslexia_font, cjk_font)

	var theme: Theme = applier.build_theme(&"ja", true)
	assert_eq(theme.get_font(&"font", &"Control"), cjk_font, "CJK locale should use CJK font even when dyslexia is enabled")

func test_build_theme_uses_dyslexia_font_for_non_cjk_locale() -> void:
	var default_font := FontFile.new()
	var dyslexia_font := FontFile.new()
	var cjk_font := FontFile.new()
	var applier := U_LOCALIZATION_FONT_APPLIER.new()
	applier.set_fonts(default_font, dyslexia_font, cjk_font)

	var theme: Theme = applier.build_theme(&"en", true)
	assert_eq(theme.get_font(&"font", &"Control"), dyslexia_font, "Non-CJK locale should use dyslexia font when enabled")

func test_build_theme_assigns_font_for_all_supported_control_types() -> void:
	var default_font := FontFile.new()
	var dyslexia_font := FontFile.new()
	var cjk_font := FontFile.new()
	var applier := U_LOCALIZATION_FONT_APPLIER.new()
	applier.set_fonts(default_font, dyslexia_font, cjk_font)

	var theme: Theme = applier.build_theme(&"en", false)
	for type_name: StringName in U_LOCALIZATION_FONT_APPLIER.FONT_THEME_TYPES:
		assert_eq(theme.get_font(&"font", type_name), default_font, "Theme should assign default font for type: %s" % str(type_name))

func test_build_theme_returns_null_when_fonts_missing() -> void:
	var applier := U_LOCALIZATION_FONT_APPLIER.new()
	applier.set_fonts(null, null, null)

	var theme: Theme = applier.build_theme(&"en", false)
	assert_null(theme, "Missing fonts should produce null theme")

func test_apply_theme_to_root_is_noop_when_theme_missing() -> void:
	var applier := U_LOCALIZATION_FONT_APPLIER.new()
	var root := Control.new()
	add_child_autofree(root)
	var original_theme := Theme.new()
	root.theme = original_theme

	applier.apply_theme_to_root(root, null)
	assert_eq(root.theme, original_theme, "Applying null theme should not modify root theme")

func test_apply_theme_to_root_applies_to_canvas_layer_control_children() -> void:
	var applier := U_LOCALIZATION_FONT_APPLIER.new()
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var control_child := Control.new()
	layer.add_child(control_child)
	var theme := Theme.new()

	applier.apply_theme_to_root(layer, theme)
	assert_eq(control_child.theme, theme, "CanvasLayer direct Control children should receive theme")
