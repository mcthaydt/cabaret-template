extends GutTest

# Tests for U_LocalizationReducer (Phase 0 - Task 0C.1)
# Note: Phase 0.5A adds test_mark_language_selected_sets_flag (total becomes 16).


func _make_state() -> Dictionary:
	return {
		"current_locale": &"en",
		"dyslexia_font_enabled": false,
		"ui_scale_override": 1.0,
		"has_selected_language": false,
	}


# Test 1: set_locale to English
func test_set_locale_to_english() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"en")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["current_locale"], &"en")


# Test 2: set_locale to Spanish
func test_set_locale_to_spanish() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"es")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["current_locale"], &"es")


# Test 3: set_locale to Portuguese
func test_set_locale_to_portuguese() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"pt")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["current_locale"], &"pt")


# Test 4: set_locale to Chinese (Simplified)
func test_set_locale_to_chinese() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"zh_CN")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["current_locale"], &"zh_CN")


# Test 5: set_locale to Japanese
func test_set_locale_to_japanese() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"ja")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["current_locale"], &"ja")


# Test 6: Unknown locale is ignored (returns same state)
func test_unknown_locale_ignored() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"fr")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["current_locale"], &"en", "Unknown locale should not change current_locale")


# Test 7: zh_CN sets ui_scale_override to CJK value (1.1)
func test_set_locale_zh_CN_sets_cjk_scale() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"zh_CN")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_almost_eq(float(new_state["ui_scale_override"]), 1.1, 0.0001)


# Test 8: ja sets ui_scale_override to CJK value (1.1)
func test_set_locale_ja_sets_cjk_scale() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_locale(&"ja")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_almost_eq(float(new_state["ui_scale_override"]), 1.1, 0.0001)


# Test 9: en resets ui_scale_override to 1.0
func test_set_locale_en_resets_scale() -> void:
	var state := _make_state()
	state["ui_scale_override"] = 1.1
	var action: Dictionary = U_LocalizationActions.set_locale(&"en")
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_almost_eq(float(new_state["ui_scale_override"]), 1.0, 0.0001)


# Test 10: set_dyslexia_font_enabled true
func test_set_dyslexia_font_enabled_true() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_dyslexia_font_enabled(true)
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["dyslexia_font_enabled"], true)


# Test 11: set_dyslexia_font_enabled false
func test_set_dyslexia_font_enabled_false() -> void:
	var state := _make_state()
	state["dyslexia_font_enabled"] = true
	var action: Dictionary = U_LocalizationActions.set_dyslexia_font_enabled(false)
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["dyslexia_font_enabled"], false)


# Test 12: set_ui_scale_override clamps at lower bound (0.5)
func test_set_ui_scale_override_clamp_lower() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_ui_scale_override(0.1)
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_almost_eq(float(new_state["ui_scale_override"]), 0.5, 0.0001)


# Test 13: set_ui_scale_override clamps at upper bound (2.0)
func test_set_ui_scale_override_clamp_upper() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.set_ui_scale_override(9.9)
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_almost_eq(float(new_state["ui_scale_override"]), 2.0, 0.0001)


# Test 14: Reducer is immutable (old state not mutated)
func test_reducer_immutability() -> void:
	var state := _make_state()
	var original_locale: StringName = state["current_locale"]
	var action: Dictionary = U_LocalizationActions.set_locale(&"es")
	var _new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(state["current_locale"], original_locale, "Original state should not be mutated")


# Test 15 (Phase 0.5A): mark_language_selected sets has_selected_language to true
func test_mark_language_selected_sets_flag() -> void:
	var state := _make_state()
	var action: Dictionary = U_LocalizationActions.mark_language_selected()
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state["has_selected_language"], true)


# Test 16: Unknown action returns same state
func test_unknown_action_returns_same_state() -> void:
	var state := _make_state()
	var action: Dictionary = {"type": StringName("unknown/action"), "payload": {}}
	var new_state: Dictionary = U_LocalizationReducer.reduce(state, action)
	assert_eq(new_state, state, "Unknown action should return same state")
