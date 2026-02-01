extends GutTest

# Tests for RS_DisplayInitialState resource (Phase 0 - Task 0A.1)

const RS_DisplayInitialState := preload("res://scripts/resources/state/rs_display_initial_state.gd")

var initial_state: RS_DisplayInitialState

func before_each() -> void:
	initial_state = RS_DisplayInitialState.new()

func after_each() -> void:
	initial_state = null

# Test 1: Has window_size_preset field
func test_has_window_size_preset_field() -> void:
	assert_true(
		"window_size_preset" in initial_state,
		"RS_DisplayInitialState should have window_size_preset field"
	)
	assert_eq(initial_state.window_size_preset, "1920x1080")

# Test 2: Has window_mode field
func test_has_window_mode_field() -> void:
	assert_true(
		"window_mode" in initial_state,
		"RS_DisplayInitialState should have window_mode field"
	)
	assert_eq(initial_state.window_mode, "windowed")

# Test 3: Has vsync_enabled field
func test_has_vsync_enabled_field() -> void:
	assert_true(
		"vsync_enabled" in initial_state,
		"RS_DisplayInitialState should have vsync_enabled field"
	)
	assert_eq(initial_state.vsync_enabled, true)

# Test 4: Has quality_preset field
func test_has_quality_preset_field() -> void:
	assert_true(
		"quality_preset" in initial_state,
		"RS_DisplayInitialState should have quality_preset field"
	)
	assert_eq(initial_state.quality_preset, "high")

# Test 5: Has film grain fields
func test_has_film_grain_fields() -> void:
	assert_true(
		"film_grain_enabled" in initial_state,
		"RS_DisplayInitialState should have film_grain_enabled field"
	)
	assert_true(
		"film_grain_intensity" in initial_state,
		"RS_DisplayInitialState should have film_grain_intensity field"
	)
	assert_eq(initial_state.film_grain_enabled, false)
	assert_eq(initial_state.film_grain_intensity, 0.1)

# Test 6: Has outline fields
func test_has_outline_fields() -> void:
	assert_true(
		"outline_enabled" in initial_state,
		"RS_DisplayInitialState should have outline_enabled field"
	)
	assert_true(
		"outline_thickness" in initial_state,
		"RS_DisplayInitialState should have outline_thickness field"
	)
	assert_true(
		"outline_color" in initial_state,
		"RS_DisplayInitialState should have outline_color field"
	)
	assert_eq(initial_state.outline_enabled, false)
	assert_eq(initial_state.outline_thickness, 2)
	assert_eq(initial_state.outline_color, "000000")

# Test 7: Has dither fields
func test_has_dither_fields() -> void:
	assert_true(
		"dither_enabled" in initial_state,
		"RS_DisplayInitialState should have dither_enabled field"
	)
	assert_true(
		"dither_intensity" in initial_state,
		"RS_DisplayInitialState should have dither_intensity field"
	)
	assert_true(
		"dither_pattern" in initial_state,
		"RS_DisplayInitialState should have dither_pattern field"
	)
	assert_eq(initial_state.dither_enabled, false)
	assert_eq(initial_state.dither_intensity, 0.5)
	assert_eq(initial_state.dither_pattern, "bayer")

# Test 8: Has LUT fields
func test_has_lut_fields() -> void:
	assert_true(
		"lut_enabled" in initial_state,
		"RS_DisplayInitialState should have lut_enabled field"
	)
	assert_true(
		"lut_resource" in initial_state,
		"RS_DisplayInitialState should have lut_resource field"
	)
	assert_true(
		"lut_intensity" in initial_state,
		"RS_DisplayInitialState should have lut_intensity field"
	)
	assert_eq(initial_state.lut_enabled, false)
	assert_eq(initial_state.lut_resource, "")
	assert_eq(initial_state.lut_intensity, 1.0)

# Test 9: Has ui_scale field
func test_has_ui_scale_field() -> void:
	assert_true(
		"ui_scale" in initial_state,
		"RS_DisplayInitialState should have ui_scale field"
	)
	assert_eq(initial_state.ui_scale, 1.0)

# Test 10: Has accessibility fields
func test_has_accessibility_fields() -> void:
	assert_true(
		"color_blind_mode" in initial_state,
		"RS_DisplayInitialState should have color_blind_mode field"
	)
	assert_true(
		"high_contrast_enabled" in initial_state,
		"RS_DisplayInitialState should have high_contrast_enabled field"
	)
	assert_true(
		"color_blind_shader_enabled" in initial_state,
		"RS_DisplayInitialState should have color_blind_shader_enabled field"
	)
	assert_eq(initial_state.color_blind_mode, "normal")
	assert_eq(initial_state.high_contrast_enabled, false)
	assert_eq(initial_state.color_blind_shader_enabled, false)

# Test 11: to_dictionary returns all fields
func test_to_dictionary_returns_all_fields() -> void:
	var dict: Dictionary = initial_state.to_dictionary()

	assert_true(dict.has("window_size_preset"), "to_dictionary should include window_size_preset")
	assert_true(dict.has("window_mode"), "to_dictionary should include window_mode")
	assert_true(dict.has("vsync_enabled"), "to_dictionary should include vsync_enabled")
	assert_true(dict.has("quality_preset"), "to_dictionary should include quality_preset")

	assert_true(dict.has("film_grain_enabled"), "to_dictionary should include film_grain_enabled")
	assert_true(dict.has("film_grain_intensity"), "to_dictionary should include film_grain_intensity")
	assert_true(dict.has("outline_enabled"), "to_dictionary should include outline_enabled")
	assert_true(dict.has("outline_thickness"), "to_dictionary should include outline_thickness")
	assert_true(dict.has("outline_color"), "to_dictionary should include outline_color")
	assert_true(dict.has("dither_enabled"), "to_dictionary should include dither_enabled")
	assert_true(dict.has("dither_intensity"), "to_dictionary should include dither_intensity")
	assert_true(dict.has("dither_pattern"), "to_dictionary should include dither_pattern")
	assert_true(dict.has("lut_enabled"), "to_dictionary should include lut_enabled")
	assert_true(dict.has("lut_resource"), "to_dictionary should include lut_resource")
	assert_true(dict.has("lut_intensity"), "to_dictionary should include lut_intensity")

	assert_true(dict.has("ui_scale"), "to_dictionary should include ui_scale")
	assert_true(dict.has("color_blind_mode"), "to_dictionary should include color_blind_mode")
	assert_true(dict.has("high_contrast_enabled"), "to_dictionary should include high_contrast_enabled")
	assert_true(dict.has("color_blind_shader_enabled"), "to_dictionary should include color_blind_shader_enabled")
