extends GutTest

## Unit tests for U_CinemaGradeSelectors
##
## Validates:
## - All 13 selectors return their documented defaults when state is empty
## - All selectors correctly read explicit values from state
## - get_cinema_grade_settings() returns only cinema_grade_* keys
## - Selectors handle missing/malformed display slice gracefully

const U_CINEMA_GRADE_SELECTORS := preload("res://scripts/state/selectors/u_cinema_grade_selectors.gd")


# --- Default value tests ---

func test_filter_mode_returns_zero_by_default() -> void:
	assert_eq(U_CINEMA_GRADE_SELECTORS.get_filter_mode({}), 0,
		"filter_mode default should be 0")


func test_filter_intensity_returns_one_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_filter_intensity({}), 1.0, 0.001,
		"filter_intensity default should be 1.0")


func test_exposure_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_exposure({}), 0.0, 0.001,
		"exposure default should be 0.0")


func test_brightness_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_brightness({}), 0.0, 0.001,
		"brightness default should be 0.0")


func test_contrast_returns_one_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_contrast({}), 1.0, 0.001,
		"contrast default should be 1.0")


func test_brilliance_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_brilliance({}), 0.0, 0.001,
		"brilliance default should be 0.0")


func test_highlights_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_highlights({}), 0.0, 0.001,
		"highlights default should be 0.0")


func test_shadows_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_shadows({}), 0.0, 0.001,
		"shadows default should be 0.0")


func test_saturation_returns_one_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_saturation({}), 1.0, 0.001,
		"saturation default should be 1.0")


func test_vibrance_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_vibrance({}), 0.0, 0.001,
		"vibrance default should be 0.0")


func test_warmth_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_warmth({}), 0.0, 0.001,
		"warmth default should be 0.0")


func test_tint_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_tint({}), 0.0, 0.001,
		"tint default should be 0.0")


func test_sharpness_returns_zero_by_default() -> void:
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_sharpness({}), 0.0, 0.001,
		"sharpness default should be 0.0")


# --- Read-from-state tests ---

func test_filter_mode_reads_from_state() -> void:
	var state := {"display": {"cinema_grade_filter_mode": 6}}
	assert_eq(U_CINEMA_GRADE_SELECTORS.get_filter_mode(state), 6,
		"filter_mode should read 6 from state")


func test_filter_intensity_reads_from_state() -> void:
	var state := {"display": {"cinema_grade_filter_intensity": 0.47}}
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_filter_intensity(state), 0.47, 0.001,
		"filter_intensity should read 0.47 from state")


func test_exposure_reads_from_state() -> void:
	var state := {"display": {"cinema_grade_exposure": -0.18}}
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_exposure(state), -0.18, 0.001,
		"exposure should read -0.18 from state")


func test_contrast_reads_from_state() -> void:
	var state := {"display": {"cinema_grade_contrast": 1.23}}
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_contrast(state), 1.23, 0.001,
		"contrast should read 1.23 from state")


func test_saturation_reads_from_state() -> void:
	var state := {"display": {"cinema_grade_saturation": 1.37}}
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_saturation(state), 1.37, 0.001,
		"saturation should read 1.37 from state")


# --- get_cinema_grade_settings tests ---

func test_get_cinema_grade_settings_returns_cinema_grade_keys() -> void:
	var state := {
		"display": {
			"cinema_grade_filter_mode": 1,
			"cinema_grade_exposure": 0.5,
			"other_setting": true,
		}
	}
	var result := U_CINEMA_GRADE_SELECTORS.get_cinema_grade_settings(state)
	assert_true(result.has("cinema_grade_filter_mode"),
		"Result should include cinema_grade_filter_mode")
	assert_true(result.has("cinema_grade_exposure"),
		"Result should include cinema_grade_exposure")


func test_get_cinema_grade_settings_excludes_non_cinema_keys() -> void:
	var state := {
		"display": {
			"cinema_grade_filter_mode": 1,
			"other_setting": true,
			"post_processing_enabled": false,
		}
	}
	var result := U_CINEMA_GRADE_SELECTORS.get_cinema_grade_settings(state)
	assert_false(result.has("other_setting"),
		"Result should not include non-cinema_grade_ keys")
	assert_false(result.has("post_processing_enabled"),
		"Result should not include post_processing_enabled")


func test_get_cinema_grade_settings_empty_when_no_cinema_keys() -> void:
	var state := {"display": {"post_processing_enabled": false, "film_grain_enabled": false}}
	var result := U_CINEMA_GRADE_SELECTORS.get_cinema_grade_settings(state)
	assert_eq(result.size(), 0, "No cinema_grade_ keys in state should return empty dict")


# --- Graceful handling tests ---

func test_selectors_handle_missing_display_slice() -> void:
	var state := {"navigation": {}}
	assert_eq(U_CINEMA_GRADE_SELECTORS.get_filter_mode(state), 0,
		"Missing display slice should return default filter_mode=0")
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_filter_intensity(state), 1.0, 0.001,
		"Missing display slice should return default filter_intensity=1.0")
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_contrast(state), 1.0, 0.001,
		"Missing display slice should return default contrast=1.0")


func test_selectors_handle_empty_state() -> void:
	var state := {}
	assert_eq(U_CINEMA_GRADE_SELECTORS.get_filter_mode(state), 0)
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_exposure(state), 0.0, 0.001)
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_contrast(state), 1.0, 0.001)
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_saturation(state), 1.0, 0.001)
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_filter_intensity(state), 1.0, 0.001)


func test_selectors_handle_non_dict_display_slice() -> void:
	var state := {"display": "bad_value"}
	assert_eq(U_CINEMA_GRADE_SELECTORS.get_filter_mode(state), 0,
		"Non-dict display slice should return default filter_mode=0")
	assert_almost_eq(U_CINEMA_GRADE_SELECTORS.get_exposure(state), 0.0, 0.001,
		"Non-dict display slice should return default exposure=0.0")
