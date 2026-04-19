extends GutTest

## Tests for post-processing preset intensity values

const CFG_LIGHT_PRESET := preload("res://resources/display/cfg_post_processing_presets/cfg_post_processing_light.tres")
const CFG_MEDIUM_PRESET := preload("res://resources/display/cfg_post_processing_presets/cfg_post_processing_medium.tres")
const CFG_HEAVY_PRESET := preload("res://resources/display/cfg_post_processing_presets/cfg_post_processing_heavy.tres")


func test_light_preset_has_lower_intensities() -> void:
	# GIVEN: Light preset values
	var light := U_PostProcessingPresetValues.get_preset_values("light")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Light should have lower intensities than medium
	assert_true(light.get("film_grain_intensity") < medium.get("film_grain_intensity"), "Light film grain should be lower")
	assert_true(light.get("dither_intensity") < medium.get("dither_intensity"), "Light dither should be lower")

func test_heavy_preset_has_higher_intensities() -> void:
	# GIVEN: Heavy preset values
	var heavy := U_PostProcessingPresetValues.get_preset_values("heavy")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Heavy should have higher intensities than medium (or equal for dither which is maxed)
	assert_true(heavy.get("film_grain_intensity") > medium.get("film_grain_intensity"), "Heavy film grain should be higher")
	assert_true(heavy.get("dither_intensity") >= medium.get("dither_intensity"), "Heavy dither should be >= medium (both maxed at 1.0)")

func test_medium_preset_has_default_values() -> void:
	# GIVEN: Medium preset values
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Should match canonical medium preset resource values
	assert_eq(medium.get("film_grain_intensity"), CFG_MEDIUM_PRESET.film_grain_intensity, "Medium film grain should match preset resource")
	assert_eq(medium.get("dither_intensity"), CFG_MEDIUM_PRESET.dither_intensity, "Medium dither should match preset resource")

func test_get_value_returns_specific_field() -> void:
	# WHEN: Getting a specific field from heavy preset
	var grain: float = U_PostProcessingPresetValues.get_value("heavy", "film_grain_intensity")

	# THEN: Should return the heavy preset's film grain intensity
	assert_eq(grain, CFG_HEAVY_PRESET.film_grain_intensity, "Heavy film grain should match preset resource")

func test_invalid_preset_returns_medium_defaults() -> void:
	# WHEN: Getting values for invalid preset
	var values := U_PostProcessingPresetValues.get_preset_values("invalid")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")

	# THEN: Should return medium values as default
	assert_eq(values.get("film_grain_intensity"), medium.get("film_grain_intensity"), "Should default to medium")

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

func test_loaded_presets_match_canonical_resources() -> void:
	var light := U_PostProcessingPresetValues.get_preset_values("light")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")
	var heavy := U_PostProcessingPresetValues.get_preset_values("heavy")

	assert_eq(light.get("film_grain_intensity"), CFG_LIGHT_PRESET.film_grain_intensity)
	assert_eq(medium.get("film_grain_intensity"), CFG_MEDIUM_PRESET.film_grain_intensity)
	assert_eq(heavy.get("film_grain_intensity"), CFG_HEAVY_PRESET.film_grain_intensity)

func test_presets_expose_scanline_fields() -> void:
	var light := U_PostProcessingPresetValues.get_preset_values("light")
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")
	var heavy := U_PostProcessingPresetValues.get_preset_values("heavy")

	assert_true(light.has("scanline_intensity"), "light should expose scanline_intensity")
	assert_true(medium.has("scanline_intensity"), "medium should expose scanline_intensity")
	assert_true(heavy.has("scanline_intensity"), "heavy should expose scanline_intensity")

	assert_almost_eq(float(light.get("scanline_intensity")), 0.0, 0.0001,
		"light scanline_intensity should be 0 (off)")
	assert_true(float(medium.get("scanline_intensity")) > 0.0,
		"medium scanline_intensity should be positive")
	assert_true(float(heavy.get("scanline_intensity")) > 0.0,
		"heavy scanline_intensity should be positive")

func test_medium_preset_scanline_count_matches_resource() -> void:
	var medium := U_PostProcessingPresetValues.get_preset_values("medium")
	assert_almost_eq(float(medium.get("scanline_count")), CFG_MEDIUM_PRESET.scanline_count, 0.0001,
		"scanline_count should match preset resource")
