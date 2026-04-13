extends GutTest

# Tests for U_DisplayReducer (Phase 0 - Task 0C.1)

const DEFAULT_DISPLAY_CONFIG := preload("res://resources/base_settings/display/cfg_display_config_default.tres")

# Test 1: Default state has all fields
func test_default_state_has_all_fields() -> void:
	var default_state: Dictionary = U_DisplayReducer.get_default_display_state()

	assert_true(default_state.has("window_size_preset"))
	assert_true(default_state.has("window_mode"))
	assert_true(default_state.has("vsync_enabled"))
	assert_true(default_state.has("quality_preset"))
	assert_true(default_state.has("film_grain_enabled"))
	assert_true(default_state.has("film_grain_intensity"))
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
	var medium_values: Dictionary = U_PostProcessingPresetValues.get_preset_values("medium")

	assert_eq(default_state.get("window_size_preset"), "1920x1080")
	assert_eq(default_state.get("window_mode"), "windowed")
	assert_eq(default_state.get("vsync_enabled"), true)
	assert_eq(default_state.get("quality_preset"), "high")
	assert_eq(default_state.get("film_grain_enabled"), false)
	assert_almost_eq(
		float(default_state.get("film_grain_intensity", 0.0)),
		float(medium_values.get("film_grain_intensity", 0.0)),
		0.0001
	)
	assert_eq(default_state.get("dither_enabled"), false)
	assert_almost_eq(
		float(default_state.get("dither_intensity", 0.0)),
		float(medium_values.get("dither_intensity", 0.0)),
		0.0001
	)
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

# Test 18: set_ui_scale clamps
func test_set_ui_scale_clamps() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_ui_scale(3.0)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	var expected_max: float = float(DEFAULT_DISPLAY_CONFIG.get("max_ui_scale"))
	assert_almost_eq(float(reduced.get("ui_scale", 0.0)), expected_max, 0.0001)

func test_set_ui_scale_clamps_to_config_min() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_ui_scale(0.01)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	var expected_min: float = float(DEFAULT_DISPLAY_CONFIG.get("min_ui_scale"))
	assert_almost_eq(float(reduced.get("ui_scale", 0.0)), expected_min, 0.0001)

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
	var heavy_values: Dictionary = U_PostProcessingPresetValues.get_preset_values("heavy")

	# THEN: State should update preset and apply heavy intensity values
	assert_eq(reduced.get("post_processing_preset"), "heavy", "Should set preset to heavy")
	assert_eq(reduced.get("film_grain_intensity"), heavy_values.get("film_grain_intensity"), "Should apply heavy film grain intensity")
	assert_eq(reduced.get("dither_intensity"), heavy_values.get("dither_intensity"), "Should apply heavy dither intensity")

# Test 27: post-processing preset light values
func test_post_processing_preset_light_applies_correct_values() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_post_processing_preset("light")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)
	var light_values: Dictionary = U_PostProcessingPresetValues.get_preset_values("light")

	# THEN: State should update preset and apply light intensity values
	assert_eq(reduced.get("post_processing_preset"), "light", "Should set preset to light")
	assert_eq(reduced.get("film_grain_intensity"), light_values.get("film_grain_intensity"), "Should apply light film grain intensity")
	assert_eq(reduced.get("dither_intensity"), light_values.get("dither_intensity"), "Should apply light dither intensity")

# Test 28: post-processing preset medium values
func test_post_processing_preset_medium_applies_current_defaults() -> void:
	var state := _make_display_state()
	var action := U_DisplayActions.set_post_processing_preset("medium")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)
	var medium_values: Dictionary = U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: State should update preset and apply medium (current default) intensity values
	assert_eq(reduced.get("post_processing_preset"), "medium", "Should set preset to medium")
	assert_eq(reduced.get("film_grain_intensity"), medium_values.get("film_grain_intensity"), "Should apply medium film grain intensity")
	assert_eq(reduced.get("dither_intensity"), medium_values.get("dither_intensity"), "Should apply medium dither intensity")

# --- Cinema Grade: ACTION_SET_PARAMETER ---

# Test 29: set_parameter filter_preset maps string to numeric mode and stores preset name
func test_set_parameter_filter_preset_dramatic_maps_to_mode_1() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("filter_preset", "dramatic")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("cinema_grade_filter_mode"), 1, "dramatic maps to mode 1")
	assert_eq(reduced.get("cinema_grade_filter_preset"), "dramatic", "preset name stored")

# Test 30: set_parameter filter_preset vivid_cold maps to mode 6
func test_set_parameter_filter_preset_vivid_cold_maps_to_mode_6() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("filter_preset", "vivid_cold")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("cinema_grade_filter_mode"), 6, "vivid_cold maps to mode 6")
	assert_eq(reduced.get("cinema_grade_filter_preset"), "vivid_cold")

# Test 31: set_parameter filter_preset none maps to mode 0
func test_set_parameter_filter_preset_none_maps_to_mode_0() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("filter_preset", "none")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("cinema_grade_filter_mode"), 0, "none maps to mode 0")
	assert_eq(reduced.get("cinema_grade_filter_preset"), "none")

# Test 32: set_parameter unknown filter_preset falls back to mode 0
func test_set_parameter_unknown_filter_preset_falls_back_to_mode_0() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("filter_preset", "not_a_preset")
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_eq(reduced.get("cinema_grade_filter_mode"), 0, "unknown preset falls back to mode 0")
	assert_eq(reduced.get("cinema_grade_filter_preset"), "not_a_preset", "preset name still stored")

# Test 33: set_parameter filter_intensity stores value directly as cinema_grade_filter_intensity
func test_set_parameter_filter_intensity_stores_value() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("filter_intensity", 0.75)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("cinema_grade_filter_intensity", 0.0)), 0.75, 0.0001)

# Test 34: set_parameter generic param is stored under cinema_grade_ prefixed key
func test_set_parameter_generic_param_stores_as_cinema_grade_key() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("exposure", 0.5)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("cinema_grade_exposure", 0.0)), 0.5, 0.0001)

# Test 35: set_parameter empty param_name returns null
func test_set_parameter_empty_param_name_returns_null() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.set_parameter("", 1.0)
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Empty param_name should return null")

# --- Cinema Grade: ACTION_RESET_TO_SCENE_DEFAULTS ---

# Test 36: reset_to_scene_defaults applies cinema_grade_ prefixed keys from payload
func test_reset_to_scene_defaults_applies_cinema_grade_keys() -> void:
	var state := _make_display_state()
	var grade_dict := {
		"cinema_grade_exposure": -0.2,
		"cinema_grade_contrast": 1.1,
		"cinema_grade_saturation": 0.9,
	}
	var action := U_CinemaGradeActions.reset_to_scene_defaults(grade_dict)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("cinema_grade_exposure", 0.0)), -0.2, 0.0001)
	assert_almost_eq(float(reduced.get("cinema_grade_contrast", 0.0)), 1.1, 0.0001)
	assert_almost_eq(float(reduced.get("cinema_grade_saturation", 0.0)), 0.9, 0.0001)

# Test 37: reset_to_scene_defaults ignores keys without cinema_grade_ prefix
func test_reset_to_scene_defaults_ignores_non_cinema_grade_keys() -> void:
	var state := _make_display_state()
	var grade_dict := {
		"cinema_grade_exposure": 0.3,
		"window_size_preset": "640x480",
	}
	var action := U_CinemaGradeActions.reset_to_scene_defaults(grade_dict)
	var reduced: Dictionary = U_DisplayReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("cinema_grade_exposure", 0.0)), 0.3, 0.0001)
	assert_eq(
		reduced.get("window_size_preset"),
		state.get("window_size_preset"),
		"Non-cinema_grade key should be ignored"
	)

# Test 38: reset_to_scene_defaults with empty payload returns null
func test_reset_to_scene_defaults_empty_payload_returns_null() -> void:
	var state := _make_display_state()
	var action := U_CinemaGradeActions.reset_to_scene_defaults({})
	var reduced: Variant = U_DisplayReducer.reduce(state, action)

	assert_null(reduced, "Empty grade dict should return null")

func _make_display_state() -> Dictionary:
	return U_DisplayReducer.get_default_display_state()
