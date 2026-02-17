extends GutTest

# Tests for U_LocalizationSelectors (Phase 0 - Task 0D.1)
# Note: Phase 0.5A adds has_selected_language tests (total becomes 9).


func _make_state_with_locale(locale: StringName, dyslexia: bool, scale: float) -> Dictionary:
	return {
		"localization": {
			"current_locale": locale,
			"dyslexia_font_enabled": dyslexia,
			"ui_scale_override": scale,
		}
	}


# Test 1: get_locale returns &"en" when slice missing
func test_get_locale_returns_default() -> void:
	var state: Dictionary = {}
	assert_eq(U_LocalizationSelectors.get_locale(state), &"en")


# Test 2: get_locale returns correct value from state
func test_get_locale_returns_value() -> void:
	var state := _make_state_with_locale(&"es", false, 1.0)
	assert_eq(U_LocalizationSelectors.get_locale(state), &"es")


# Test 3: is_dyslexia_font_enabled returns false when slice missing
func test_is_dyslexia_font_enabled_returns_default() -> void:
	var state: Dictionary = {}
	assert_eq(U_LocalizationSelectors.is_dyslexia_font_enabled(state), false)


# Test 4: is_dyslexia_font_enabled returns correct value from state
func test_is_dyslexia_font_enabled_returns_value() -> void:
	var state := _make_state_with_locale(&"en", true, 1.0)
	assert_eq(U_LocalizationSelectors.is_dyslexia_font_enabled(state), true)


# Test 5: get_ui_scale_override returns 1.0 when slice missing
func test_get_ui_scale_override_returns_default() -> void:
	var state: Dictionary = {}
	assert_almost_eq(U_LocalizationSelectors.get_ui_scale_override(state), 1.0, 0.0001)


# Test 6: get_ui_scale_override returns correct value from state
func test_get_ui_scale_override_returns_value() -> void:
	var state := _make_state_with_locale(&"zh_CN", false, 1.1)
	assert_almost_eq(U_LocalizationSelectors.get_ui_scale_override(state), 1.1, 0.0001)


# Test 7 (Phase 0.5A): has_selected_language returns false when field absent
func test_has_selected_language_returns_default() -> void:
	var state: Dictionary = {}
	assert_eq(U_LocalizationSelectors.has_selected_language(state), false)


# Test 8 (Phase 0.5A): has_selected_language returns true when field is true
func test_has_selected_language_returns_true() -> void:
	var state: Dictionary = {"localization": {"has_selected_language": true}}
	assert_eq(U_LocalizationSelectors.has_selected_language(state), true)


# Test 9: All selectors handle missing localization slice gracefully (no crash)
func test_selectors_handle_missing_localization_slice() -> void:
	var state: Dictionary = {"other_slice": {}}
	# None of these should crash
	var locale: StringName = U_LocalizationSelectors.get_locale(state)
	var dyslexia: bool = U_LocalizationSelectors.is_dyslexia_font_enabled(state)
	var scale: float = U_LocalizationSelectors.get_ui_scale_override(state)

	assert_eq(locale, &"en")
	assert_eq(dyslexia, false)
	assert_almost_eq(scale, 1.0, 0.0001)
