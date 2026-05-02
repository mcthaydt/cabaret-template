extends GutTest

const CATALOG_PATH := "res://scripts/core/ui/helpers/u_ui_settings_catalog.gd"


func test_display_options_use_expected_entry_shape() -> void:
	var catalog := _get_catalog()
	if catalog == null:
		return
	_assert_option_entries(catalog.get_window_sizes(), true)
	_assert_option_entries(catalog.get_window_modes())
	_assert_option_entries(catalog.get_vsync_options())
	_assert_option_entries(catalog.get_quality_presets())

	var ui_scale_range: Dictionary = catalog.get_ui_scale_range()
	_assert_range(ui_scale_range, true)


func test_audio_options_use_expected_defaults() -> void:
	var catalog := _get_catalog()
	if catalog == null:
		return
	var bus_names: Array[String] = catalog.get_audio_bus_names()
	assert_eq(bus_names, ["Master", "Music", "SFX", "Ambient"], "Audio buses should match settings tabs")

	var volume_range: Dictionary = catalog.get_volume_range()
	_assert_range(volume_range)
	assert_eq(catalog.get_default_volume(), 0.8, "Default volume should match audio defaults")
	assert_true(catalog.get_spatial_audio_default(), "Spatial audio should default enabled")


func test_vfx_options_use_expected_entry_shape() -> void:
	var catalog := _get_catalog()
	if catalog == null:
		return
	var toggles: Array[Dictionary] = catalog.get_toggle_options()
	assert_eq(toggles.size(), 5, "VFX catalog should expose all toggle settings")
	for entry in toggles:
		assert_true(entry.has("key"), "Toggle entry should include key")
		assert_true(entry.get("key") is StringName, "Toggle key should be StringName")
		assert_true(entry.has("label_key"), "Toggle entry should include label_key")
		assert_true(entry.get("label_key") is StringName, "Toggle label_key should be StringName")
		assert_true(entry.has("tooltip_key"), "Toggle entry should include tooltip_key")
		assert_true(entry.get("tooltip_key") is StringName, "Toggle tooltip_key should be StringName")
		assert_true(entry.has("default"), "Toggle entry should include default")
		assert_true(entry.get("default") is bool, "Toggle default should be bool")

	var intensity_range: Dictionary = catalog.get_intensity_range()
	_assert_range(intensity_range, true)


func test_methods_return_fresh_arrays() -> void:
	var catalog := _get_catalog()
	if catalog == null:
		return
	var window_modes: Array[Dictionary] = catalog.get_window_modes()
	window_modes.clear()
	assert_gt(catalog.get_window_modes().size(), 0, "Window modes should be fresh arrays")

	var audio_buses: Array[String] = catalog.get_audio_bus_names()
	audio_buses.clear()
	assert_gt(catalog.get_audio_bus_names().size(), 0, "Audio bus names should be fresh arrays")

	var toggles: Array[Dictionary] = catalog.get_toggle_options()
	toggles.clear()
	assert_gt(catalog.get_toggle_options().size(), 0, "VFX toggles should be fresh arrays")


func _get_catalog() -> GDScript:
	if not ResourceLoader.exists(CATALOG_PATH):
		assert_true(false, "U_UISettingsCatalog script should exist")
		return null
	var catalog := load(CATALOG_PATH) as GDScript
	assert_not_null(catalog, "U_UISettingsCatalog script should exist")
	return catalog


func _assert_option_entries(entries: Array, expect_value: bool = false) -> void:
	assert_gt(entries.size(), 0, "Option catalog should not be empty")
	for entry in entries:
		assert_true(entry is Dictionary, "Option entries should be dictionaries")
		assert_true(entry.has("id"), "Option entry should include id")
		assert_true(entry.get("id") is StringName, "Option id should be StringName")
		assert_true(entry.has("label_key"), "Option entry should include label_key")
		assert_true(entry.get("label_key") is StringName, "Option label_key should be StringName")
		if expect_value:
			assert_true(entry.has("value"), "Option entry should include value")


func _assert_range(range: Dictionary, expect_default: bool = false) -> void:
	assert_true(range.has("min"), "Range should include min")
	assert_true(range.has("max"), "Range should include max")
	assert_true(range.has("step"), "Range should include step")
	if expect_default:
		assert_true(range.has("default"), "Range should include default")
