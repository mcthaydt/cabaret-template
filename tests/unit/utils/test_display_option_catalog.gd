extends GutTest

const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/utils/display/u_display_option_catalog.gd")

func test_window_size_presets_sorted_by_order() -> void:
	var presets := U_DISPLAY_OPTION_CATALOG.get_window_size_presets()
	var ids: Array[String] = []
	for preset in presets:
		ids.append(String(preset.preset_id))
	assert_eq(ids, ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"],
		"Window size presets should be sorted by sort_order")

func test_quality_presets_sorted_by_order() -> void:
	var presets := U_DISPLAY_OPTION_CATALOG.get_quality_presets()
	var ids: Array[String] = []
	for preset in presets:
		ids.append(preset.preset_name)
	assert_eq(ids, ["low", "medium", "high", "ultra"],
		"Quality presets should be sorted by sort_order")

func test_option_entries_include_labels() -> void:
	var window_entries := U_DISPLAY_OPTION_CATALOG.get_window_size_option_entries()
	assert_true(window_entries.size() >= 5, "Window size entries should be populated")
	assert_true(String(window_entries[0].get("label", "")).length() > 0,
		"Window size entries should include labels")

	var quality_entries := U_DISPLAY_OPTION_CATALOG.get_quality_option_entries()
	assert_true(quality_entries.size() >= 4, "Quality preset entries should be populated")
	assert_true(String(quality_entries[0].get("label", "")).length() > 0,
		"Quality preset entries should include labels")

func test_window_mode_options() -> void:
	var entries := U_DISPLAY_OPTION_CATALOG.get_window_mode_option_entries()
	var ids: Array[String] = []
	for entry in entries:
		ids.append(String(entry.get("id", "")))
	assert_eq(ids, ["windowed", "fullscreen", "borderless"],
		"Window mode options should match expected ids")

func test_dither_pattern_options() -> void:
	var entries := U_DISPLAY_OPTION_CATALOG.get_dither_pattern_option_entries()
	var ids: Array[String] = []
	for entry in entries:
		ids.append(String(entry.get("id", "")))
	assert_eq(ids, ["bayer", "noise"], "Dither pattern options should match expected ids")

func test_color_blind_mode_options() -> void:
	var entries := U_DISPLAY_OPTION_CATALOG.get_color_blind_mode_option_entries()
	var ids: Array[String] = []
	for entry in entries:
		ids.append(String(entry.get("id", "")))
	assert_eq(ids, ["normal", "deuteranopia", "protanopia", "tritanopia"],
		"Color blind mode options should match expected ids")
