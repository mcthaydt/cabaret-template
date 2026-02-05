extends GutTest

## Tests for post-processing preset intensity values

const U_PostProcessingPresetValues := preload("res://scripts/utils/display/u_post_processing_preset_values.gd")

func test_light_preset_has_lower_intensities() -> void:
	# GIVEN: Light preset values
	var light := U_PostProcessingPresetValues.get_preset_values("light")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Light should have lower intensities than medium
	assert_true(light.get("film_grain_intensity") < medium.get("film_grain_intensity"), "Light film grain should be lower")
	assert_true(light.get("crt_scanline_intensity") < medium.get("crt_scanline_intensity"), "Light scanlines should be lower")
	assert_true(light.get("dither_intensity") < medium.get("dither_intensity"), "Light dither should be lower")

func test_heavy_preset_has_higher_intensities() -> void:
	# GIVEN: Heavy preset values
	var heavy := U_PostProcessingPresetValues.get_preset_values("heavy")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Heavy should have higher intensities than medium
	assert_true(heavy.get("film_grain_intensity") > medium.get("film_grain_intensity"), "Heavy film grain should be higher")
	assert_true(heavy.get("crt_scanline_intensity") > medium.get("crt_scanline_intensity"), "Heavy scanlines should be higher")
	assert_true(heavy.get("dither_intensity") > medium.get("dither_intensity"), "Heavy dither should be higher")

func test_medium_preset_has_default_values() -> void:
	# GIVEN: Medium preset values
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Should match documented defaults
	assert_eq(medium.get("film_grain_intensity"), 0.1, "Medium film grain should be 0.1")
	assert_eq(medium.get("crt_scanline_intensity"), 0.3, "Medium scanlines should be 0.3")
	assert_eq(medium.get("crt_curvature"), 2.0, "Medium curvature should be 2.0")
	assert_eq(medium.get("crt_chromatic_aberration"), 0.002, "Medium aberration should be 0.002")
	assert_eq(medium.get("dither_intensity"), 0.5, "Medium dither should be 0.5")

func test_get_value_returns_specific_field() -> void:
	# WHEN: Getting a specific field from heavy preset
	var grain: float = U_PostProcessingPresetValues.get_value("heavy", "film_grain_intensity")

	# THEN: Should return the heavy preset's film grain intensity
	assert_eq(grain, 0.2, "Heavy film grain should be 0.2")

func test_invalid_preset_returns_medium_defaults() -> void:
	# WHEN: Getting values for invalid preset
	var values := U_PostProcessingPresetValues.get_preset_values("invalid")

	# THEN: Should return medium values as default
	assert_eq(values.get("film_grain_intensity"), 0.1, "Should default to medium")

func test_is_valid_preset() -> void:
	# THEN: Valid presets should return true
	assert_true(U_PostProcessingPresetValues.is_valid_preset("light"), "Light should be valid")
	assert_true(U_PostProcessingPresetValues.is_valid_preset("medium"), "Medium should be valid")
	assert_true(U_PostProcessingPresetValues.is_valid_preset("heavy"), "Heavy should be valid")
	assert_false(U_PostProcessingPresetValues.is_valid_preset("invalid"), "Invalid should return false")

func test_get_preset_names() -> void:
	# WHEN: Getting all preset names
	var names := U_PostProcessingPresetValues.get_preset_names()

	# THEN: Should contain all three presets
	assert_true(names.has("light"), "Should have light")
	assert_true(names.has("medium"), "Should have medium")
	assert_true(names.has("heavy"), "Should have heavy")
	assert_eq(names.size(), 3, "Should have exactly 3 presets")
