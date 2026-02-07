extends GutTest

# Tests for U_DisplayActions action creators (Phase 0 - Task 0B.1)

const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")

# Test 1: set_window_size_preset action
func test_set_window_size_preset_action() -> void:
	var action: Dictionary = U_DisplayActions.set_window_size_preset("1920x1080")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_WINDOW_SIZE_PRESET)
	assert_eq(payload.get("preset"), "1920x1080")
	assert_eq(action.get("immediate"), true)

# Test 2: set_window_mode action
func test_set_window_mode_action() -> void:
	var action: Dictionary = U_DisplayActions.set_window_mode("fullscreen")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_WINDOW_MODE)
	assert_eq(payload.get("mode"), "fullscreen")
	assert_eq(action.get("immediate"), true)

# Test 3: set_vsync_enabled action
func test_set_vsync_enabled_action() -> void:
	var action: Dictionary = U_DisplayActions.set_vsync_enabled(false)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_VSYNC_ENABLED)
	assert_eq(payload.get("enabled"), false)
	assert_eq(action.get("immediate"), true)

# Test 4: set_quality_preset action
func test_set_quality_preset_action() -> void:
	var action: Dictionary = U_DisplayActions.set_quality_preset("ultra")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_QUALITY_PRESET)
	assert_eq(payload.get("preset"), "ultra")
	assert_eq(action.get("immediate"), true)

# Test 5: set_film_grain_enabled action
func test_set_film_grain_enabled_action() -> void:
	var action: Dictionary = U_DisplayActions.set_film_grain_enabled(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_FILM_GRAIN_ENABLED)
	assert_eq(payload.get("enabled"), true)
	assert_eq(action.get("immediate"), true)

# Test 6: set_film_grain_intensity action
func test_set_film_grain_intensity_action() -> void:
	var action: Dictionary = U_DisplayActions.set_film_grain_intensity(0.25)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_FILM_GRAIN_INTENSITY)
	assert_eq(payload.get("intensity"), 0.25)
	assert_eq(action.get("immediate"), true)

# Test 7: set_crt_enabled action
func test_set_crt_enabled_action() -> void:
	var action: Dictionary = U_DisplayActions.set_crt_enabled(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_CRT_ENABLED)
	assert_eq(payload.get("enabled"), true)
	assert_eq(action.get("immediate"), true)

# Test 8: set_crt_scanline_intensity action
func test_set_crt_scanline_intensity_action() -> void:
	var action: Dictionary = U_DisplayActions.set_crt_scanline_intensity(0.5)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_CRT_SCANLINE_INTENSITY)
	assert_almost_eq(float(payload.get("intensity", 0.0)), 0.5, 0.0001)
	assert_eq(action.get("immediate"), true)

# Test 9: set_crt_curvature action
func test_set_crt_curvature_action() -> void:
	var action: Dictionary = U_DisplayActions.set_crt_curvature(5.0)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_CRT_CURVATURE)
	assert_almost_eq(float(payload.get("curvature", 0.0)), 5.0, 0.0001)
	assert_eq(action.get("immediate"), true)

# Test 10: set_dither_enabled action
func test_set_dither_enabled_action() -> void:
	var action: Dictionary = U_DisplayActions.set_dither_enabled(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_DITHER_ENABLED)
	assert_eq(payload.get("enabled"), true)
	assert_eq(action.get("immediate"), true)

# Test 11: set_dither_intensity action
func test_set_dither_intensity_action() -> void:
	var action: Dictionary = U_DisplayActions.set_dither_intensity(0.75)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_DITHER_INTENSITY)
	assert_eq(payload.get("intensity"), 0.75)
	assert_eq(action.get("immediate"), true)

# Test 12: set_dither_pattern action
func test_set_dither_pattern_action() -> void:
	var action: Dictionary = U_DisplayActions.set_dither_pattern("noise")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_DITHER_PATTERN)
	assert_eq(payload.get("pattern"), "noise")
	assert_eq(action.get("immediate"), true)

# Test 13: set_ui_scale action
func test_set_ui_scale_action() -> void:
	var action: Dictionary = U_DisplayActions.set_ui_scale(1.5)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_UI_SCALE)
	assert_eq(payload.get("scale"), 1.5)
	assert_eq(action.get("immediate"), true)

# Test 14: set_color_blind_mode action
func test_set_color_blind_mode_action() -> void:
	var action: Dictionary = U_DisplayActions.set_color_blind_mode("deuteranopia")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_COLOR_BLIND_MODE)
	assert_eq(payload.get("mode"), "deuteranopia")
	assert_eq(action.get("immediate"), true)

# Test 15: set_high_contrast_enabled action
func test_set_high_contrast_enabled_action() -> void:
	var action: Dictionary = U_DisplayActions.set_high_contrast_enabled(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_HIGH_CONTRAST_ENABLED)
	assert_eq(payload.get("enabled"), true)
	assert_eq(action.get("immediate"), true)

# Test 16: set_color_blind_shader_enabled action
func test_set_color_blind_shader_enabled_action() -> void:
	var action: Dictionary = U_DisplayActions.set_color_blind_shader_enabled(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_DisplayActions.ACTION_SET_COLOR_BLIND_SHADER_ENABLED)
	assert_eq(payload.get("enabled"), true)
	assert_eq(action.get("immediate"), true)
