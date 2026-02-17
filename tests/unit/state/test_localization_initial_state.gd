extends GutTest

# Tests for RS_LocalizationInitialState resource (Phase 0 - Task 0A.1)
# Note: Phase 0.5A adds a 4th field `has_selected_language` and updates test count to 6.


var initial_state: RS_LocalizationInitialState

func before_each() -> void:
	initial_state = RS_LocalizationInitialState.new()

func after_each() -> void:
	initial_state = null


# Test 1: Has current_locale field with default "en"
func test_has_current_locale_field() -> void:
	assert_true(
		"current_locale" in initial_state,
		"RS_LocalizationInitialState should have current_locale field"
	)
	assert_eq(initial_state.current_locale, "en")


# Test 2: Has dyslexia_font_enabled field with default false
func test_has_dyslexia_font_enabled_field() -> void:
	assert_true(
		"dyslexia_font_enabled" in initial_state,
		"RS_LocalizationInitialState should have dyslexia_font_enabled field"
	)
	assert_eq(initial_state.dyslexia_font_enabled, false)


# Test 3: Has ui_scale_override field with default 1.0
func test_has_ui_scale_override_field() -> void:
	assert_true(
		"ui_scale_override" in initial_state,
		"RS_LocalizationInitialState should have ui_scale_override field"
	)
	assert_eq(initial_state.ui_scale_override, 1.0)


# Test 4: to_dictionary returns all 4 fields (updated in Phase 0.5A)
func test_to_dictionary_returns_all_fields() -> void:
	var dict: Dictionary = initial_state.to_dictionary()

	assert_true(dict.has("current_locale"), "to_dictionary should include current_locale")
	assert_true(dict.has("dyslexia_font_enabled"), "to_dictionary should include dyslexia_font_enabled")
	assert_true(dict.has("ui_scale_override"), "to_dictionary should include ui_scale_override")
	assert_true(dict.has("has_selected_language"), "to_dictionary should include has_selected_language")


# Test 6 (Phase 0.5A): has_selected_language field exists with default false
func test_has_selected_language_default() -> void:
	assert_true(
		"has_selected_language" in initial_state,
		"RS_LocalizationInitialState should have has_selected_language field"
	)
	assert_eq(initial_state.has_selected_language, false)


# Test 5: Defaults match reducer defaults (current_locale as StringName)
func test_defaults_match_reducer() -> void:
	var dict: Dictionary = initial_state.to_dictionary()

	assert_eq(dict["current_locale"], &"en", "current_locale should serialize as StringName &'en'")
	assert_eq(dict["dyslexia_font_enabled"], false)
	assert_eq(dict["ui_scale_override"], 1.0)
