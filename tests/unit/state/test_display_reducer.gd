extends GutTest

# Tests for U_DisplayReducer (Phase 0 - Task 0C.1)

const U_DisplayReducer := preload("res://scripts/state/reducers/u_display_reducer.gd")
const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")

# Test 1: Default state has all fields
func test_default_state_has_all_fields() -> void:
	var default_state: Dictionary = U_DisplayReducer.get_default_display_state()

	assert_true(default_state.has("window_size_preset"))
	assert_true(default_state.has("window_mode"))
	assert_true(default_state.has("vsync_enabled"))
	assert_true(default_state.has("quality_preset"))
	assert_true(default_state.has("film_grain_enabled"))
	assert_true(default_state.has("film_grain_intensity"))
	assert_true(default_state.has("crt_enabled"))
	assert_true(default_state.has("crt_scanline_intensity"))
	assert_true(default_state.has("crt_curvature"))
	assert_true(default_state.has("dither_enabled"))
	assert_true(default_state.has("dither_intensity"))
	assert_true(default_state.has("dither_pattern"))
	assert_true(default_state.has("ui_scale"))
	assert_true(default_state.has("color_blind_mode"))
	assert_true(default_state.has("high_contrast_enabled"))
	assert_true(default_state.has("color_blind_shader_enabled"))

# Test 2: Default values are expected
func test_default_state_has_expected_defaults() -> void:
	var default_state: Dictionary = U_DisplayReducer.get_default_display_state()

	assert_eq(default_state.get("window_size_preset"), "1920x1080")
	assert_eq(default_state.get("window_mode"), "windowed")
	assert_eq(default_state.get("vsync_enabled"), true)
	assert_eq(default_state.get("quality_preset"), "high")
	assert_eq(default_state.get("film_grain_enabled"), false)
	assert_almost_eq(float(default_state.get("film_grain_intensity", 0.0)), 0.2, 0.0001)
	assert_eq(default_state.get("crt_enabled"), false)
	assert_almost_eq(float(default_state.get("crt_scanline_intensity", 0.0)), 0.25, 0.0001)
	assert_almost_eq(float(default_state.get("crt_curvature", 0.0)), 0.0, 0.0001)
	assert_eq(default_state.get("dither_enabled"), false)
	assert_almost_eq(float(default_state.get("dither_intensity", 0.0)), 1.0, 0.0001)
	assert_eq(default_state.get("dither_pattern"), "bayer")
	assert_almost_eq(float(default_state.get("ui_scale", 0.0)), 1.0, 0.0001)
	assert_eq(default_state.get("color_blind_mode"), "normal")
	assert_eq(default_state.get("high_contrast_enabled"), false)
	assert_eq(default_state.get("color_blind_shader_enabled"), false)

# Test 3: set_window_size_preset updates field
func test_set_window_size_preset_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_window_size_preset("2560x1440")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("window_size_preset"), "2560x1440")

# Test 4: set_window_mode updates field
func test_set_window_mode_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_window_mode("fullscreen")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("window_mode"), "fullscreen")

# Test 5: set_vsync_enabled updates field
func test_set_vsync_enabled_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_vsync_enabled(false)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("vsync_enabled"), false)

# Test 6: set_quality_preset updates field
func test_set_quality_preset_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_quality_preset("ultra")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("quality_preset"), "ultra")

# Test 7: set_film_grain_enabled updates field
func test_set_film_grain_enabled_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_film_grain_enabled(true)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("film_grain_enabled"), true)

# Test 8: set_crt_enabled updates field
func test_set_crt_enabled_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_crt_enabled(true)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("crt_enabled"), true)

# Test 9: set_crt_curvature updates field
func test_set_crt_curvature_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_crt_curvature(5.0)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("crt_curvature", 0.0)), 5.0, 0.0001)

# Test 10: set_dither_enabled updates field
func test_set_dither_enabled_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_dither_enabled(true)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("dither_enabled"), true)

# Test 11: set_dither_pattern updates field
func test_set_dither_pattern_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_dither_pattern("noise")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("dither_pattern"), "noise")

# Test 12: set_color_blind_mode updates field
func test_set_color_blind_mode_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_color_blind_mode("deuteranopia")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("color_blind_mode"), "deuteranopia")

# Test 13: set_high_contrast_enabled updates field
func test_set_high_contrast_enabled_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_high_contrast_enabled(true)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("high_contrast_enabled"), true)

# Test 14: set_color_blind_shader_enabled updates field
func test_set_color_blind_shader_enabled_updates_field() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_color_blind_shader_enabled(true)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("color_blind_shader_enabled"), true)

# Test 15: set_film_grain_intensity clamps
func test_set_film_grain_intensity_clamps() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_film_grain_intensity(2.0)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("film_grain_intensity", 0.0)), 1.0, 0.0001)

# Test 16: set_dither_intensity clamps
func test_set_dither_intensity_clamps() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_dither_intensity(-1.0)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("dither_intensity", 0.0)), 0.0, 0.0001)

# Test 17: set_crt_scanline_intensity clamps
func test_set_crt_scanline_intensity_clamps() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_crt_scanline_intensity(10.0)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("crt_scanline_intensity", 0.0)), 1.0, 0.0001)

# Test 18: set_ui_scale clamps
func test_set_ui_scale_clamps() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_ui_scale(3.0)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("ui_scale", 0.0)), 1.3, 0.0001)

# Test 19: invalid window_size_preset ignored
func test_invalid_window_size_preset_ignored() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_window_size_preset("999x999")
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Invalid window_size_preset should return null")

# Test 20: invalid window_mode ignored
func test_invalid_window_mode_ignored() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_window_mode("invalid")
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Invalid window_mode should return null")

# Test 21: invalid quality_preset ignored
func test_invalid_quality_preset_ignored() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_quality_preset("potato")
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Invalid quality_preset should return null")

# Test 22: invalid color_blind_mode ignored
func test_invalid_color_blind_mode_ignored() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_color_blind_mode("achromatopsia")
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Invalid color_blind_mode should return null")

# Test 23: invalid dither_pattern ignored
func test_invalid_dither_pattern_ignored() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_dither_pattern("ordered")
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Invalid dither_pattern should return null")

# Test 24: unknown action returns null
func test_unhandled_action_returns_null() -> void:
	var state := _make_display_state()
	var action := {"type": StringName("display/unknown_action")}
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Unknown action should return null (no change)")

# Test 25: reducer immutability
func test_reducer_immutability() -> void:
	var state := _make_display_state()
	var original_copy: Dictionary = state.duplicate(true)
	var action := U_DisplayActions.set_vsync_enabled(false)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_ne(state, reduced, "Reducer should return a new state object")
	assert_eq(state, original_copy, "Original state should remain unchanged")

# Test 26: post-processing preset applies intensity values
func test_post_processing_preset_applies_intensity_values() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_post_processing_preset("heavy")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	# THEN: State should update preset and apply heavy intensity values
	assert_eq(reduced.get("post_processing_preset"), "heavy", "Should set preset to heavy")
	assert_eq(reduced.get("film_grain_intensity"), 0.35, "Should apply heavy film grain intensity")
	assert_eq(reduced.get("crt_scanline_intensity"), 0.45, "Should apply heavy scanline intensity")
	assert_eq(reduced.get("crt_curvature"), 3.0, "Should apply heavy curvature")
	assert_eq(reduced.get("crt_chromatic_aberration"), 0.004, "Should apply heavy aberration")
	assert_eq(reduced.get("dither_intensity"), 1.0, "Should apply heavy dither intensity")

# Test 27: post-processing preset light values
func test_post_processing_preset_light_applies_correct_values() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_post_processing_preset("light")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	# THEN: State should update preset and apply light intensity values
	assert_eq(reduced.get("post_processing_preset"), "light", "Should set preset to light")
	assert_eq(reduced.get("film_grain_intensity"), 0.05, "Should apply light film grain intensity")
	assert_eq(reduced.get("crt_scanline_intensity"), 0.15, "Should apply light scanline intensity")
	assert_eq(reduced.get("crt_curvature"), 1.0, "Should apply light curvature")
	assert_eq(reduced.get("crt_chromatic_aberration"), 0.001, "Should apply light aberration")
	assert_eq(reduced.get("dither_intensity"), 0.25, "Should apply light dither intensity")

# Test 28: post-processing preset medium values
func test_post_processing_preset_medium_applies_current_defaults() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_post_processing_preset("medium")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	# THEN: State should update preset and apply medium (current default) intensity values
	assert_eq(reduced.get("post_processing_preset"), "medium", "Should set preset to medium")
	assert_eq(reduced.get("film_grain_intensity"), 0.2, "Should apply medium film grain intensity")
	assert_eq(reduced.get("crt_scanline_intensity"), 0.25, "Should apply medium scanline intensity")
	assert_eq(reduced.get("crt_curvature"), 0.0, "Should apply medium curvature")
	assert_eq(reduced.get("crt_chromatic_aberration"), 0.001, "Should apply medium aberration")
	assert_eq(reduced.get("dither_intensity"), 1.0, "Should apply medium dither intensity")

func _make_display_state() -> Dictionary:
	return U_DisplayReducer.get_default_display_state()
