extends GutTest

const BASE_OVERLAY_SCRIPT := "res://scripts/ui/settings/base_settings_simple_overlay.gd"
const AUDIO_OVERLAY_SCRIPT := "res://scripts/ui/settings/ui_audio_settings_overlay.gd"
const DISPLAY_OVERLAY_SCRIPT := "res://scripts/ui/settings/ui_display_settings_overlay.gd"
const LOCALIZATION_OVERLAY_SCRIPT := "res://scripts/ui/settings/ui_localization_settings_overlay.gd"
const VFX_OVERLAY_SCRIPT := "res://scripts/ui/settings/ui_vfx_settings_overlay.gd"

const MAX_CONCRETE_LINES := 15


func test_base_settings_simple_overlay_class_exists() -> void:
	var base_script := load(BASE_OVERLAY_SCRIPT) as GDScript
	assert_not_null(base_script, "BaseSettingsSimpleOverlay script should exist")


func test_audio_overlay_extends_base_simple_overlay() -> void:
	var base_script := load(BASE_OVERLAY_SCRIPT) as GDScript
	var overlay_script := load(AUDIO_OVERLAY_SCRIPT) as GDScript
	if base_script == null or overlay_script == null:
		assert_false(true, "Scripts should load")
		return
	assert_eq(overlay_script.get_base_script(), base_script, "UI_AudioSettingsOverlay should extend BaseSettingsSimpleOverlay")


func test_display_overlay_extends_base_simple_overlay() -> void:
	var base_script := load(BASE_OVERLAY_SCRIPT) as GDScript
	var overlay_script := load(DISPLAY_OVERLAY_SCRIPT) as GDScript
	if base_script == null or overlay_script == null:
		assert_false(true, "Scripts should load")
		return
	assert_eq(overlay_script.get_base_script(), base_script, "UI_DisplaySettingsOverlay should extend BaseSettingsSimpleOverlay")


func test_localization_overlay_extends_base_simple_overlay() -> void:
	var base_script := load(BASE_OVERLAY_SCRIPT) as GDScript
	var overlay_script := load(LOCALIZATION_OVERLAY_SCRIPT) as GDScript
	if base_script == null or overlay_script == null:
		assert_false(true, "Scripts should load")
		return
	assert_eq(overlay_script.get_base_script(), base_script, "UI_LocalizationSettingsOverlay should extend BaseSettingsSimpleOverlay")


func test_vfx_overlay_does_not_extend_base_simple_overlay() -> void:
	var base_script := load(BASE_OVERLAY_SCRIPT) as GDScript
	var vfx_script := load(VFX_OVERLAY_SCRIPT) as GDScript
	if base_script == null or vfx_script == null:
		assert_false(true, "Scripts should load")
		return
	assert_ne(vfx_script.get_base_script(), base_script, "VFX overlay should NOT extend BaseSettingsSimpleOverlay")


func test_base_has_shared_methods() -> void:
	var file := FileAccess.open(BASE_OVERLAY_SCRIPT, FileAccess.READ)
	if file == null:
		assert_false(true, "BaseSettingsSimpleOverlay source should be readable")
		return
	var source := file.get_as_text()
	file.close()
	assert_true("_on_panel_ready" in source, "Base should define _on_panel_ready")
	assert_true("_on_back_pressed" in source, "Base should define _on_back_pressed")
	assert_true("_apply_theme_tokens" in source, "Base should define _apply_theme_tokens")
	assert_true("_close_overlay" in source, "Base should define _close_overlay")


func test_audio_overlay_script_under_line_limit() -> void:
	_assert_script_line_count(AUDIO_OVERLAY_SCRIPT, "UI_AudioSettingsOverlay")


func test_display_overlay_script_under_line_limit() -> void:
	_assert_script_line_count(DISPLAY_OVERLAY_SCRIPT, "UI_DisplaySettingsOverlay")


func test_localization_overlay_script_under_line_limit() -> void:
	_assert_script_line_count(LOCALIZATION_OVERLAY_SCRIPT, "UI_LocalizationSettingsOverlay")


func _assert_script_line_count(script_path: String, class_label: String) -> void:
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		assert_false(true, "%s script should be readable" % class_label)
		return
	var line_count := 0
	while not file.eof_reached():
		file.get_line()
		line_count += 1
	file.close()
	assert_true(
		line_count <= MAX_CONCRETE_LINES,
		"%s should be under %d lines (got %d)" % [class_label, MAX_CONCRETE_LINES, line_count]
	)