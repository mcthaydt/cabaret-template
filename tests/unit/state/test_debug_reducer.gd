extends GutTest


func test_set_disable_touchscreen_updates_state() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_disable_touchscreen(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("disable_touchscreen", false), "Reducer should set disable_touchscreen flag")
	assert_false(state.get("disable_touchscreen", true), "Original state should remain unchanged")

func test_unhandled_action_returns_null() -> void:
	var result: Variant = U_DebugReducer.reduce({}, {"type": StringName("noop")})
	assert_null(result, "Unknown actions should return null to signal no change")

func test_selector_reads_flag() -> void:
	var reduced: Dictionary = U_DebugReducer.reduce(U_DebugReducer.get_default_debug_state(), U_DebugActions.set_disable_touchscreen(true)) as Dictionary
	var wrapped_state: Dictionary = {"debug": reduced}
	assert_true(U_DebugSelectors.is_touchscreen_disabled(wrapped_state), "Selector should surface disable flag")
	var settings := U_DebugSelectors.get_debug_settings(wrapped_state)
	assert_true(settings.get("disable_touchscreen", false))


# --- skip_splash ---

func test_set_skip_splash_updates_state() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_skip_splash(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("skip_splash", false), "Reducer should set skip_splash flag")
	assert_false(state.get("skip_splash", true), "Original state should remain unchanged")

func test_skip_splash_selector_reads_flag() -> void:
	var reduced: Dictionary = U_DebugReducer.reduce(U_DebugReducer.get_default_debug_state(), U_DebugActions.set_skip_splash(true)) as Dictionary
	var wrapped_state: Dictionary = {"debug": reduced}
	assert_true(U_DebugSelectors.should_skip_splash(wrapped_state), "Selector should surface skip_splash flag")

func test_skip_splash_defaults_to_false() -> void:
	var wrapped_state: Dictionary = {"debug": U_DebugReducer.get_default_debug_state()}
	assert_false(U_DebugSelectors.should_skip_splash(wrapped_state), "skip_splash should default to false")


# --- skip_language_selection ---

func test_set_skip_language_selection_updates_state() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_skip_language_selection(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("skip_language_selection", false), "Reducer should set skip_language_selection flag")
	assert_false(state.get("skip_language_selection", true), "Original state should remain unchanged")

func test_skip_language_selection_selector_reads_flag() -> void:
	var reduced: Dictionary = U_DebugReducer.reduce(U_DebugReducer.get_default_debug_state(), U_DebugActions.set_skip_language_selection(true)) as Dictionary
	var wrapped_state: Dictionary = {"debug": reduced}
	assert_true(U_DebugSelectors.should_skip_language_selection(wrapped_state), "Selector should surface skip_language_selection flag")

func test_skip_language_selection_defaults_to_false() -> void:
	var wrapped_state: Dictionary = {"debug": U_DebugReducer.get_default_debug_state()}
	assert_false(U_DebugSelectors.should_skip_language_selection(wrapped_state), "skip_language_selection should default to false")


# --- skip_main_menu ---

func test_set_skip_main_menu_updates_state() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_skip_main_menu(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("skip_main_menu", false), "Reducer should set skip_main_menu flag")
	assert_false(state.get("skip_main_menu", true), "Original state should remain unchanged")

func test_skip_main_menu_selector_reads_flag() -> void:
	var reduced: Dictionary = U_DebugReducer.reduce(U_DebugReducer.get_default_debug_state(), U_DebugActions.set_skip_main_menu(true)) as Dictionary
	var wrapped_state: Dictionary = {"debug": reduced}
	assert_true(U_DebugSelectors.should_skip_main_menu(wrapped_state), "Selector should surface skip_main_menu flag")

func test_skip_main_menu_defaults_to_false() -> void:
	var wrapped_state: Dictionary = {"debug": U_DebugReducer.get_default_debug_state()}
	assert_false(U_DebugSelectors.should_skip_main_menu(wrapped_state), "skip_main_menu should default to false")


# --- boot_skips_consumed (one-shot guard) ---

func test_set_boot_skips_consumed_updates_state() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_boot_skips_consumed(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("boot_skips_consumed", false), "Reducer should set boot_skips_consumed flag")
	assert_false(state.get("boot_skips_consumed", true), "Original state should remain unchanged")

func test_boot_skips_consumed_defaults_to_false() -> void:
	var wrapped_state: Dictionary = {"debug": U_DebugReducer.get_default_debug_state()}
	assert_false(U_DebugSelectors.are_boot_skips_consumed(wrapped_state), "boot_skips_consumed should default to false")

func test_skip_main_menu_blocked_after_boot_skips_consumed() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	# Enable skip_main_menu
	state = U_DebugReducer.reduce(state, U_DebugActions.set_skip_main_menu(true)) as Dictionary
	# Mark boot skips as consumed
	state = U_DebugReducer.reduce(state, U_DebugActions.set_boot_skips_consumed(true)) as Dictionary
	var wrapped_state: Dictionary = {"debug": state}
	assert_true(U_DebugSelectors.should_skip_main_menu(wrapped_state), "Raw flag should still be true")
	assert_true(U_DebugSelectors.are_boot_skips_consumed(wrapped_state), "boot_skips_consumed should be true")

func test_skip_main_menu_allowed_before_boot_skips_consumed() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	state = U_DebugReducer.reduce(state, U_DebugActions.set_skip_main_menu(true)) as Dictionary
	var wrapped_state: Dictionary = {"debug": state}
	assert_true(U_DebugSelectors.should_skip_main_menu(wrapped_state), "skip_main_menu should be true")
	assert_false(U_DebugSelectors.are_boot_skips_consumed(wrapped_state), "boot_skips_consumed should be false")
