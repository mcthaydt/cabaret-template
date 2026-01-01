extends GutTest

const U_DebugSelectors := preload("res://scripts/state/selectors/u_debug_selectors.gd")

# Phase 1 TDD Tests - Debug Selectors

func test_is_god_mode_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"god_mode": true}}

	assert_true(U_DebugSelectors.is_god_mode(state), "Should return true when god mode enabled")

func test_is_god_mode_returns_false_when_disabled() -> void:
	var state: Dictionary = {"debug": {"god_mode": false}}

	assert_false(U_DebugSelectors.is_god_mode(state), "Should return false when god mode disabled")

func test_is_god_mode_returns_false_when_field_missing() -> void:
	var state: Dictionary = {"debug": {}}

	assert_false(U_DebugSelectors.is_god_mode(state), "Should return false when god_mode field missing (default)")

func test_is_god_mode_returns_false_when_debug_slice_missing() -> void:
	var state: Dictionary = {}

	assert_false(U_DebugSelectors.is_god_mode(state), "Should return false when debug slice missing (default)")

func test_is_infinite_jump_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"infinite_jump": true}}

	assert_true(U_DebugSelectors.is_infinite_jump(state), "Should return true when infinite jump enabled")

func test_is_infinite_jump_returns_false_when_disabled() -> void:
	var state: Dictionary = {"debug": {"infinite_jump": false}}

	assert_false(U_DebugSelectors.is_infinite_jump(state), "Should return false when infinite jump disabled")

func test_get_speed_modifier_returns_correct_value() -> void:
	var state: Dictionary = {"debug": {"speed_modifier": 2.0}}

	assert_almost_eq(U_DebugSelectors.get_speed_modifier(state), 2.0, 0.0001, "Should return 2.0 speed modifier")

func test_get_speed_modifier_returns_default_when_missing() -> void:
	var state: Dictionary = {"debug": {}}

	assert_almost_eq(U_DebugSelectors.get_speed_modifier(state), 1.0, 0.0001, "Should return default 1.0 when missing")

func test_is_gravity_disabled_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"disable_gravity": true}}

	assert_true(U_DebugSelectors.is_gravity_disabled(state), "Should return true when gravity disabled")

func test_is_gravity_disabled_returns_false_when_enabled() -> void:
	var state: Dictionary = {"debug": {"disable_gravity": false}}

	assert_false(U_DebugSelectors.is_gravity_disabled(state), "Should return false when gravity enabled")

func test_is_input_disabled_returns_true_when_disabled() -> void:
	var state: Dictionary = {"debug": {"disable_input": true}}

	assert_true(U_DebugSelectors.is_input_disabled(state), "Should return true when input disabled")

func test_is_input_disabled_returns_false_when_enabled() -> void:
	var state: Dictionary = {"debug": {"disable_input": false}}

	assert_false(U_DebugSelectors.is_input_disabled(state), "Should return false when input enabled")

func test_get_time_scale_returns_correct_value() -> void:
	var state: Dictionary = {"debug": {"time_scale": 0.5}}

	assert_almost_eq(U_DebugSelectors.get_time_scale(state), 0.5, 0.0001, "Should return 0.5 time scale")

func test_get_time_scale_returns_default_when_missing() -> void:
	var state: Dictionary = {"debug": {}}

	assert_almost_eq(U_DebugSelectors.get_time_scale(state), 1.0, 0.0001, "Should return default 1.0 when missing")

func test_is_showing_collision_shapes_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"show_collision_shapes": true}}

	assert_true(U_DebugSelectors.is_showing_collision_shapes(state), "Should return true when showing collision shapes")

func test_is_showing_collision_shapes_returns_false_when_disabled() -> void:
	var state: Dictionary = {"debug": {"show_collision_shapes": false}}

	assert_false(U_DebugSelectors.is_showing_collision_shapes(state), "Should return false when not showing collision shapes")

func test_is_showing_spawn_points_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"show_spawn_points": true}}

	assert_true(U_DebugSelectors.is_showing_spawn_points(state), "Should return true when showing spawn points")

func test_is_showing_trigger_zones_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"show_trigger_zones": true}}

	assert_true(U_DebugSelectors.is_showing_trigger_zones(state), "Should return true when showing trigger zones")

func test_is_showing_entity_labels_returns_true_when_enabled() -> void:
	var state: Dictionary = {"debug": {"show_entity_labels": true}}

	assert_true(U_DebugSelectors.is_showing_entity_labels(state), "Should return true when showing entity labels")

func test_selectors_are_pure_functions() -> void:
	var state: Dictionary = {"debug": {"god_mode": true, "speed_modifier": 2.0}}

	var result1_god := U_DebugSelectors.is_god_mode(state)
	var result2_god := U_DebugSelectors.is_god_mode(state)
	var result1_speed := U_DebugSelectors.get_speed_modifier(state)
	var result2_speed := U_DebugSelectors.get_speed_modifier(state)

	assert_eq(result1_god, result2_god, "Selector should return same result for same input (pure function)")
	assert_almost_eq(result1_speed, result2_speed, 0.0001, "Selector should return same result for same input (pure function)")

func test_selectors_do_not_mutate_state() -> void:
	var original_state: Dictionary = {"debug": {"god_mode": true, "speed_modifier": 2.0}}
	var state_copy: Dictionary = original_state.duplicate(true)

	var _result_god: bool = U_DebugSelectors.is_god_mode(original_state)
	var _result_speed: float = U_DebugSelectors.get_speed_modifier(original_state)

	assert_eq(original_state, state_copy, "Selectors should not mutate state")

func test_all_selectors_handle_null_safe_access() -> void:
	var empty_state: Dictionary = {}

	# All selectors should return safe defaults when debug slice missing
	assert_false(U_DebugSelectors.is_god_mode(empty_state))
	assert_false(U_DebugSelectors.is_infinite_jump(empty_state))
	assert_almost_eq(U_DebugSelectors.get_speed_modifier(empty_state), 1.0, 0.0001)
	assert_false(U_DebugSelectors.is_gravity_disabled(empty_state))
	assert_false(U_DebugSelectors.is_input_disabled(empty_state))
	assert_almost_eq(U_DebugSelectors.get_time_scale(empty_state), 1.0, 0.0001)
	assert_false(U_DebugSelectors.is_showing_collision_shapes(empty_state))
	assert_false(U_DebugSelectors.is_showing_spawn_points(empty_state))
	assert_false(U_DebugSelectors.is_showing_trigger_zones(empty_state))
	assert_false(U_DebugSelectors.is_showing_entity_labels(empty_state))
