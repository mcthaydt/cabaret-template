extends GutTest

# Tests for U_DisplaySelectors (Phase 0 - Task 0D.1)

const U_DisplaySelectors := preload("res://scripts/state/selectors/u_display_selectors.gd")

const DEFAULTS := {
	"window_size_preset": "1920x1080",
	"window_mode": "windowed",
	"vsync_enabled": true,
	"quality_preset": "high",
	"film_grain_enabled": false,
	"film_grain_intensity": 0.1,
	"outline_enabled": false,
	"outline_thickness": 2,
	"outline_color": "000000",
	"dither_enabled": false,
	"dither_intensity": 0.5,
	"dither_pattern": "bayer",
	"lut_enabled": false,
	"lut_resource": "",
	"lut_intensity": 1.0,
	"ui_scale": 1.0,
	"color_blind_mode": "normal",
	"high_contrast_enabled": false,
	"color_blind_shader_enabled": false,
}

# Test 1: window_size_preset selector
func test_get_window_size_preset_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["window_size_preset"] = "2560x1440"
	assert_eq(U_DisplaySelectors.get_window_size_preset(state), "2560x1440")
	assert_eq(U_DisplaySelectors.get_window_size_preset({}), DEFAULTS["window_size_preset"])
	var missing_field := _make_state()
	missing_field["display"].erase("window_size_preset")
	assert_eq(U_DisplaySelectors.get_window_size_preset(missing_field), DEFAULTS["window_size_preset"])

# Test 2: window_mode selector
func test_get_window_mode_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["window_mode"] = "fullscreen"
	assert_eq(U_DisplaySelectors.get_window_mode(state), "fullscreen")
	assert_eq(U_DisplaySelectors.get_window_mode({}), DEFAULTS["window_mode"])
	var missing_field := _make_state()
	missing_field["display"].erase("window_mode")
	assert_eq(U_DisplaySelectors.get_window_mode(missing_field), DEFAULTS["window_mode"])

# Test 3: vsync_enabled selector
func test_is_vsync_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["vsync_enabled"] = false
	assert_false(U_DisplaySelectors.is_vsync_enabled(state))
	assert_true(U_DisplaySelectors.is_vsync_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("vsync_enabled")
	assert_true(U_DisplaySelectors.is_vsync_enabled(missing_field))

# Test 4: quality_preset selector
func test_get_quality_preset_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["quality_preset"] = "ultra"
	assert_eq(U_DisplaySelectors.get_quality_preset(state), "ultra")
	assert_eq(U_DisplaySelectors.get_quality_preset({}), DEFAULTS["quality_preset"])
	var missing_field := _make_state()
	missing_field["display"].erase("quality_preset")
	assert_eq(U_DisplaySelectors.get_quality_preset(missing_field), DEFAULTS["quality_preset"])

# Test 5: film_grain_enabled selector
func test_is_film_grain_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["film_grain_enabled"] = true
	assert_true(U_DisplaySelectors.is_film_grain_enabled(state))
	assert_false(U_DisplaySelectors.is_film_grain_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("film_grain_enabled")
	assert_false(U_DisplaySelectors.is_film_grain_enabled(missing_field))

# Test 6: film_grain_intensity selector
func test_get_film_grain_intensity_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["film_grain_intensity"] = 0.25
	assert_almost_eq(U_DisplaySelectors.get_film_grain_intensity(state), 0.25, 0.0001)
	assert_almost_eq(U_DisplaySelectors.get_film_grain_intensity({}), DEFAULTS["film_grain_intensity"], 0.0001)
	var missing_field := _make_state()
	missing_field["display"].erase("film_grain_intensity")
	assert_almost_eq(U_DisplaySelectors.get_film_grain_intensity(missing_field), DEFAULTS["film_grain_intensity"], 0.0001)

# Test 7: outline_enabled selector
func test_is_outline_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["outline_enabled"] = true
	assert_true(U_DisplaySelectors.is_outline_enabled(state))
	assert_false(U_DisplaySelectors.is_outline_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("outline_enabled")
	assert_false(U_DisplaySelectors.is_outline_enabled(missing_field))

# Test 8: outline_thickness selector
func test_get_outline_thickness_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["outline_thickness"] = 4
	assert_eq(U_DisplaySelectors.get_outline_thickness(state), 4)
	assert_eq(U_DisplaySelectors.get_outline_thickness({}), DEFAULTS["outline_thickness"])
	var missing_field := _make_state()
	missing_field["display"].erase("outline_thickness")
	assert_eq(U_DisplaySelectors.get_outline_thickness(missing_field), DEFAULTS["outline_thickness"])

# Test 9: outline_color selector
func test_get_outline_color_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["outline_color"] = "ff00ff"
	assert_eq(U_DisplaySelectors.get_outline_color(state), "ff00ff")
	assert_eq(U_DisplaySelectors.get_outline_color({}), DEFAULTS["outline_color"])
	var missing_field := _make_state()
	missing_field["display"].erase("outline_color")
	assert_eq(U_DisplaySelectors.get_outline_color(missing_field), DEFAULTS["outline_color"])

# Test 10: dither_enabled selector
func test_is_dither_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["dither_enabled"] = true
	assert_true(U_DisplaySelectors.is_dither_enabled(state))
	assert_false(U_DisplaySelectors.is_dither_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("dither_enabled")
	assert_false(U_DisplaySelectors.is_dither_enabled(missing_field))

# Test 11: dither_intensity selector
func test_get_dither_intensity_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["dither_intensity"] = 0.75
	assert_almost_eq(U_DisplaySelectors.get_dither_intensity(state), 0.75, 0.0001)
	assert_almost_eq(U_DisplaySelectors.get_dither_intensity({}), DEFAULTS["dither_intensity"], 0.0001)
	var missing_field := _make_state()
	missing_field["display"].erase("dither_intensity")
	assert_almost_eq(U_DisplaySelectors.get_dither_intensity(missing_field), DEFAULTS["dither_intensity"], 0.0001)

# Test 12: dither_pattern selector
func test_get_dither_pattern_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["dither_pattern"] = "noise"
	assert_eq(U_DisplaySelectors.get_dither_pattern(state), "noise")
	assert_eq(U_DisplaySelectors.get_dither_pattern({}), DEFAULTS["dither_pattern"])
	var missing_field := _make_state()
	missing_field["display"].erase("dither_pattern")
	assert_eq(U_DisplaySelectors.get_dither_pattern(missing_field), DEFAULTS["dither_pattern"])

# Test 13: lut_enabled selector
func test_is_lut_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["lut_enabled"] = true
	assert_true(U_DisplaySelectors.is_lut_enabled(state))
	assert_false(U_DisplaySelectors.is_lut_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("lut_enabled")
	assert_false(U_DisplaySelectors.is_lut_enabled(missing_field))

# Test 14: lut_resource selector
func test_get_lut_resource_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["lut_resource"] = "res://assets/luts/test.cube"
	assert_eq(U_DisplaySelectors.get_lut_resource(state), "res://assets/luts/test.cube")
	assert_eq(U_DisplaySelectors.get_lut_resource({}), DEFAULTS["lut_resource"])
	var missing_field := _make_state()
	missing_field["display"].erase("lut_resource")
	assert_eq(U_DisplaySelectors.get_lut_resource(missing_field), DEFAULTS["lut_resource"])

# Test 15: lut_intensity selector
func test_get_lut_intensity_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["lut_intensity"] = 0.6
	assert_almost_eq(U_DisplaySelectors.get_lut_intensity(state), 0.6, 0.0001)
	assert_almost_eq(U_DisplaySelectors.get_lut_intensity({}), DEFAULTS["lut_intensity"], 0.0001)
	var missing_field := _make_state()
	missing_field["display"].erase("lut_intensity")
	assert_almost_eq(U_DisplaySelectors.get_lut_intensity(missing_field), DEFAULTS["lut_intensity"], 0.0001)

# Test 16: ui_scale selector
func test_get_ui_scale_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["ui_scale"] = 1.5
	assert_almost_eq(U_DisplaySelectors.get_ui_scale(state), 1.5, 0.0001)
	assert_almost_eq(U_DisplaySelectors.get_ui_scale({}), DEFAULTS["ui_scale"], 0.0001)
	var missing_field := _make_state()
	missing_field["display"].erase("ui_scale")
	assert_almost_eq(U_DisplaySelectors.get_ui_scale(missing_field), DEFAULTS["ui_scale"], 0.0001)

# Test 17: color_blind_mode selector
func test_get_color_blind_mode_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["color_blind_mode"] = "deuteranopia"
	assert_eq(U_DisplaySelectors.get_color_blind_mode(state), "deuteranopia")
	assert_eq(U_DisplaySelectors.get_color_blind_mode({}), DEFAULTS["color_blind_mode"])
	var missing_field := _make_state()
	missing_field["display"].erase("color_blind_mode")
	assert_eq(U_DisplaySelectors.get_color_blind_mode(missing_field), DEFAULTS["color_blind_mode"])

# Test 18: high_contrast_enabled selector
func test_is_high_contrast_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["high_contrast_enabled"] = true
	assert_true(U_DisplaySelectors.is_high_contrast_enabled(state))
	assert_false(U_DisplaySelectors.is_high_contrast_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("high_contrast_enabled")
	assert_false(U_DisplaySelectors.is_high_contrast_enabled(missing_field))

# Test 19: color_blind_shader_enabled selector
func test_is_color_blind_shader_enabled_returns_value_and_defaults() -> void:
	var state := _make_state()
	state["display"]["color_blind_shader_enabled"] = true
	assert_true(U_DisplaySelectors.is_color_blind_shader_enabled(state))
	assert_false(U_DisplaySelectors.is_color_blind_shader_enabled({}))
	var missing_field := _make_state()
	missing_field["display"].erase("color_blind_shader_enabled")
	assert_false(U_DisplaySelectors.is_color_blind_shader_enabled(missing_field))

func _make_state() -> Dictionary:
	return {
		"display": DEFAULTS.duplicate(true)
	}
