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
