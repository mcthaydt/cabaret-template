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
	assert_eq(initial_state.film_grain_enabled, false)
	# Note: film_grain_intensity is loaded from post_processing_preset, not stored directly

# Test 6: Has CRT fields
func test_has_crt_fields() -> void:
	assert_true(
		"crt_enabled" in initial_state,
		"RS_DisplayInitialState should have crt_enabled field"
	)
	assert_eq(initial_state.crt_enabled, false)
	# Note: CRT intensity values are loaded from post_processing_preset, not stored directly

# Test 7: Has dither fields
func test_has_dither_fields() -> void:
	assert_true(
		"dither_enabled" in initial_state,
		"RS_DisplayInitialState should have dither_enabled field"
	)
	assert_true(
		"dither_pattern" in initial_state,
		"RS_DisplayInitialState should have dither_pattern field"
	)
	assert_eq(initial_state.dither_enabled, false)
	assert_eq(initial_state.dither_pattern, "bayer")
	# Note: dither_intensity is loaded from post_processing_preset, not stored directly

# Test 8: Has ui_scale field
func test_has_ui_scale_field() -> void:
	assert_true(
		"ui_scale" in initial_state,
		"RS_DisplayInitialState should have ui_scale field"
	)
	assert_eq(initial_state.ui_scale, 1.0)

# Test 9: Has accessibility fields
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

# Test 10: to_dictionary returns all fields
func test_to_dictionary_returns_all_fields() -> void:
	var dict: Dictionary = initial_state.to_dictionary()

	assert_true(dict.has("window_size_preset"), "to_dictionary should include window_size_preset")
	assert_true(dict.has("window_mode"), "to_dictionary should include window_mode")
	assert_true(dict.has("vsync_enabled"), "to_dictionary should include vsync_enabled")
	assert_true(dict.has("quality_preset"), "to_dictionary should include quality_preset")

	assert_true(dict.has("film_grain_enabled"), "to_dictionary should include film_grain_enabled")
	assert_true(dict.has("film_grain_intensity"), "to_dictionary should include film_grain_intensity")
	assert_true(dict.has("crt_enabled"), "to_dictionary should include crt_enabled")
	assert_true(dict.has("crt_scanline_intensity"), "to_dictionary should include crt_scanline_intensity")
	assert_true(dict.has("crt_curvature"), "to_dictionary should include crt_curvature")
	assert_true(dict.has("dither_enabled"), "to_dictionary should include dither_enabled")
	assert_true(dict.has("dither_intensity"), "to_dictionary should include dither_intensity")
	assert_true(dict.has("dither_pattern"), "to_dictionary should include dither_pattern")

	assert_true(dict.has("ui_scale"), "to_dictionary should include ui_scale")
	assert_true(dict.has("color_blind_mode"), "to_dictionary should include color_blind_mode")
	assert_true(dict.has("high_contrast_enabled"), "to_dictionary should include high_contrast_enabled")
	assert_true(dict.has("color_blind_shader_enabled"), "to_dictionary should include color_blind_shader_enabled")

# Test 11: to_dictionary loads intensity values from preset
func test_to_dictionary_loads_intensity_values_from_preset() -> void:
	# GIVEN: Initial state with medium preset (default)
	initial_state.post_processing_preset = "medium"

	# WHEN: Converting to dictionary
	var dict: Dictionary = initial_state.to_dictionary()

	# THEN: Should have intensity values from medium preset
	assert_true(dict.has("film_grain_intensity"), "Should include film_grain_intensity")
	assert_true(dict.has("crt_scanline_intensity"), "Should include crt_scanline_intensity")
	assert_true(dict.has("crt_curvature"), "Should include crt_curvature")
	assert_true(dict.has("crt_chromatic_aberration"), "Should include crt_chromatic_aberration")
	assert_true(dict.has("dither_intensity"), "Should include dither_intensity")

	# Values should match medium preset (current defaults)
	assert_eq(dict["film_grain_intensity"], 0.1, "Should have medium preset film grain intensity")
	assert_eq(dict["crt_scanline_intensity"], 0.15, "Should have medium preset scanline intensity")
	assert_eq(dict["crt_curvature"], 0.0, "Should have medium preset curvature")
	assert_eq(dict["crt_chromatic_aberration"], 0.001, "Should have medium preset aberration")
	assert_eq(dict["dither_intensity"], 1.0, "Should have medium preset dither intensity")

# Test 12: to_dictionary respects different presets
func test_to_dictionary_respects_different_presets() -> void:
	# GIVEN: Initial state with heavy preset
	initial_state.post_processing_preset = "heavy"

	# WHEN: Converting to dictionary
	var dict: Dictionary = initial_state.to_dictionary()

	# THEN: Should have intensity values from heavy preset
	assert_eq(dict["film_grain_intensity"], 0.35, "Should have heavy preset film grain intensity")
	assert_eq(dict["crt_scanline_intensity"], 0.45, "Should have heavy preset scanline intensity")
	assert_eq(dict["crt_curvature"], 0.1, "Should have heavy preset curvature")
