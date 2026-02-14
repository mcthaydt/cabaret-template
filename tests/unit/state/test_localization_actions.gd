extends GutTest

# Tests for U_LocalizationActions action creators (Phase 0 - Task 0B.1)
# Note: Phase 0.5A adds mark_language_selected action (total becomes 5 tests).


# Test 1: set_locale action structure
func test_set_locale_action() -> void:
	var action: Dictionary = U_LocalizationActions.set_locale(&"es")
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_LocalizationActions.ACTION_SET_LOCALE)
	assert_eq(payload.get("locale"), &"es")


# Test 2: set_dyslexia_font_enabled action structure
func test_set_dyslexia_font_enabled_action() -> void:
	var action: Dictionary = U_LocalizationActions.set_dyslexia_font_enabled(true)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_LocalizationActions.ACTION_SET_DYSLEXIA_FONT_ENABLED)
	assert_eq(payload.get("enabled"), true)


# Test 3: set_ui_scale_override action structure
func test_set_ui_scale_override_action() -> void:
	var action: Dictionary = U_LocalizationActions.set_ui_scale_override(1.5)
	var payload: Dictionary = action.get("payload", {})

	assert_eq(action.get("type"), U_LocalizationActions.ACTION_SET_UI_SCALE_OVERRIDE)
	assert_eq(payload.get("scale"), 1.5)


# Test 4: All action type constants begin with "localization/" prefix
func test_action_types_use_localization_prefix() -> void:
	assert_true(
		String(U_LocalizationActions.ACTION_SET_LOCALE).begins_with("localization/"),
		"ACTION_SET_LOCALE should begin with 'localization/'"
	)
	assert_true(
		String(U_LocalizationActions.ACTION_SET_DYSLEXIA_FONT_ENABLED).begins_with("localization/"),
		"ACTION_SET_DYSLEXIA_FONT_ENABLED should begin with 'localization/'"
	)
	assert_true(
		String(U_LocalizationActions.ACTION_SET_UI_SCALE_OVERRIDE).begins_with("localization/"),
		"ACTION_SET_UI_SCALE_OVERRIDE should begin with 'localization/'"
	)
