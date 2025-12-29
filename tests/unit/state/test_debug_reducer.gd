extends GutTest

const U_DebugReducer := preload("res://scripts/state/reducers/u_debug_reducer.gd")
const U_DebugActions := preload("res://scripts/state/actions/u_debug_actions.gd")
const U_DebugSelectors := preload("res://scripts/state/selectors/u_debug_selectors.gd")

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

# Phase 1 TDD Tests - Debug Toggles

func test_reducer_is_pure_function() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_god_mode(true)

	# Call reduce twice with same inputs
	var result1: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary
	var result2: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_eq(result1, result2, "Reducer should return same output for same inputs (pure function)")

func test_reducer_does_not_mutate_original_state() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var original_god_mode := state.get("god_mode", false)

	var _reduced: Dictionary = U_DebugReducer.reduce(state, U_DebugActions.set_god_mode(true)) as Dictionary

	assert_eq(state.get("god_mode", false), original_god_mode, "Reducer should not mutate original state")

func test_set_god_mode_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_god_mode(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("god_mode", false), "Should enable god mode")
	assert_false(state.get("god_mode", true), "Original state should remain unchanged")

func test_set_god_mode_false() -> void:
	var state: Dictionary = {"god_mode": true}
	var action: Dictionary = U_DebugActions.set_god_mode(false)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_false(reduced.get("god_mode", true), "Should disable god mode")

func test_set_infinite_jump_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_infinite_jump(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("infinite_jump", false), "Should enable infinite jump")
	assert_false(state.get("infinite_jump", true), "Original state should remain unchanged")

func test_set_infinite_jump_false() -> void:
	var state: Dictionary = {"infinite_jump": true}
	var action: Dictionary = U_DebugActions.set_infinite_jump(false)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_false(reduced.get("infinite_jump", true), "Should disable infinite jump")

func test_set_speed_modifier() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_speed_modifier(2.0)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_almost_eq(reduced.get("speed_modifier", 0.0), 2.0, 0.0001, "Should set speed modifier to 2.0")
	assert_almost_eq(state.get("speed_modifier", 99.0), 1.0, 0.0001, "Original state should remain at default 1.0")

func test_set_disable_gravity_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_disable_gravity(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("disable_gravity", false), "Should disable gravity")

func test_set_disable_gravity_false() -> void:
	var state: Dictionary = {"disable_gravity": true}
	var action: Dictionary = U_DebugActions.set_disable_gravity(false)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_false(reduced.get("disable_gravity", true), "Should enable gravity")

func test_set_disable_input_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_disable_input(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("disable_input", false), "Should disable input")

func test_set_disable_input_false() -> void:
	var state: Dictionary = {"disable_input": true}
	var action: Dictionary = U_DebugActions.set_disable_input(false)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_false(reduced.get("disable_input", true), "Should enable input")

func test_set_time_scale() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_time_scale(0.5)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_almost_eq(reduced.get("time_scale", 0.0), 0.5, 0.0001, "Should set time scale to 0.5")
	assert_almost_eq(state.get("time_scale", 99.0), 1.0, 0.0001, "Original state should remain at default 1.0")

func test_set_show_collision_shapes_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_show_collision_shapes(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("show_collision_shapes", false), "Should enable collision shape rendering")

func test_set_show_collision_shapes_false() -> void:
	var state: Dictionary = {"show_collision_shapes": true}
	var action: Dictionary = U_DebugActions.set_show_collision_shapes(false)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_false(reduced.get("show_collision_shapes", true), "Should disable collision shape rendering")

func test_set_show_spawn_points_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_show_spawn_points(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("show_spawn_points", false), "Should enable spawn point markers")

func test_set_show_trigger_zones_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_show_trigger_zones(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("show_trigger_zones", false), "Should enable trigger zone outlines")

func test_set_show_entity_labels_true() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()
	var action: Dictionary = U_DebugActions.set_show_entity_labels(true)
	var reduced: Dictionary = U_DebugReducer.reduce(state, action) as Dictionary

	assert_true(reduced.get("show_entity_labels", false), "Should enable entity ID labels")

func test_default_state_has_correct_values() -> void:
	var state: Dictionary = U_DebugReducer.get_default_debug_state()

	assert_false(state.get("disable_touchscreen", true), "disable_touchscreen should default to false")
	assert_false(state.get("god_mode", true), "god_mode should default to false")
	assert_false(state.get("infinite_jump", true), "infinite_jump should default to false")
	assert_almost_eq(state.get("speed_modifier", 0.0), 1.0, 0.0001, "speed_modifier should default to 1.0")
	assert_false(state.get("disable_gravity", true), "disable_gravity should default to false")
	assert_false(state.get("disable_input", true), "disable_input should default to false")
	assert_almost_eq(state.get("time_scale", 0.0), 1.0, 0.0001, "time_scale should default to 1.0")
	assert_false(state.get("show_collision_shapes", true), "show_collision_shapes should default to false")
	assert_false(state.get("show_spawn_points", true), "show_spawn_points should default to false")
	assert_false(state.get("show_trigger_zones", true), "show_trigger_zones should default to false")
	assert_false(state.get("show_entity_labels", true), "show_entity_labels should default to false")
