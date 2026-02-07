extends GutTest

# TDD: Test post-processing effect enable logic (H1 - simplified unit test)
# Verifies that the applier checks individual toggles before enabling effects

const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")

# Test that selectors properly read individual effect toggles
func test_film_grain_selector_returns_false_by_default() -> void:
	var state := {"display": {}}
	assert_false(
		U_DISPLAY_SELECTORS.is_film_grain_enabled(state),
		"Film grain should be disabled by default"
	)

func test_film_grain_selector_returns_true_when_enabled() -> void:
	var state := {"display": {"film_grain_enabled": true}}
	assert_true(
		U_DISPLAY_SELECTORS.is_film_grain_enabled(state),
		"Film grain should be enabled when film_grain_enabled=true"
	)

func test_crt_selector_returns_false_by_default() -> void:
	var state := {"display": {}}
	assert_false(
		U_DISPLAY_SELECTORS.is_crt_enabled(state),
		"CRT should be disabled by default"
	)

func test_crt_selector_returns_true_when_enabled() -> void:
	var state := {"display": {"crt_enabled": true}}
	assert_true(
		U_DISPLAY_SELECTORS.is_crt_enabled(state),
		"CRT should be enabled when crt_enabled=true"
	)

func test_dither_selector_returns_false_by_default() -> void:
	var state := {"display": {}}
	assert_false(
		U_DISPLAY_SELECTORS.is_dither_enabled(state),
		"Dither should be disabled by default"
	)

func test_dither_selector_returns_true_when_enabled() -> void:
	var state := {"display": {"dither_enabled": true}}
	assert_true(
		U_DISPLAY_SELECTORS.is_dither_enabled(state),
		"Dither should be enabled when dither_enabled=true"
	)

# Test that default state includes all toggle fields
func test_default_display_state_includes_effect_toggles() -> void:
	const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")
	var default_state := U_DISPLAY_REDUCER.get_default_display_state()

	assert_true(
		default_state.has("film_grain_enabled"),
		"Default state should include film_grain_enabled"
	)
	assert_true(
		default_state.has("crt_enabled"),
		"Default state should include crt_enabled"
	)
	assert_true(
		default_state.has("dither_enabled"),
		"Default state should include dither_enabled"
	)

# Test reducer handles individual toggle actions
func test_reducer_handles_film_grain_toggle() -> void:
	const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
	const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")

	var state := {"film_grain_enabled": false}
	var action := U_DISPLAY_ACTIONS.set_film_grain_enabled(true)
	var next_state: Variant = U_DISPLAY_REDUCER.reduce(state, action)

	assert_not_null(next_state, "Reducer should handle film grain toggle")
	if next_state is Dictionary:
		assert_eq(
			next_state.get("film_grain_enabled"),
			true,
			"Reducer should set film_grain_enabled to true"
		)

func test_reducer_handles_crt_toggle() -> void:
	const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
	const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")

	var state := {"crt_enabled": false}
	var action := U_DISPLAY_ACTIONS.set_crt_enabled(true)
	var next_state: Variant = U_DISPLAY_REDUCER.reduce(state, action)

	assert_not_null(next_state, "Reducer should handle CRT toggle")
	if next_state is Dictionary:
		assert_eq(
			next_state.get("crt_enabled"),
			true,
			"Reducer should set crt_enabled to true"
		)

func test_reducer_handles_dither_toggle() -> void:
	const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
	const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")

	var state := {"dither_enabled": false}
	var action := U_DISPLAY_ACTIONS.set_dither_enabled(true)
	var next_state: Variant = U_DISPLAY_REDUCER.reduce(state, action)

	assert_not_null(next_state, "Reducer should handle dither toggle")
	if next_state is Dictionary:
		assert_eq(
			next_state.get("dither_enabled"),
			true,
			"Reducer should set dither_enabled to true"
		)
