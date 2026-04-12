extends GutTest

## Tests for GameplaySelectors derived state computation
## Updated for C8: selectors now accept full state dicts (not gameplay slices)


func before_each() -> void:
	U_StateEventBus.reset()

func after_each() -> void:
	U_StateEventBus.reset()

## Test get_is_paused returns true when paused
func test_get_is_paused_returns_true_when_paused() -> void:
	var state: Dictionary = {"gameplay": {"paused": true, "entities": {}}}

	var is_paused: bool = U_GameplaySelectors.get_is_paused(state)

	assert_true(is_paused, "Should return true when paused")

## Test get_is_paused returns false when not paused
func test_get_is_paused_returns_false_when_not_paused() -> void:
	var state: Dictionary = {"gameplay": {"paused": false, "entities": {}}}

	var is_paused: bool = U_GameplaySelectors.get_is_paused(state)

	assert_false(is_paused, "Should return false when not paused")

## Test get_is_paused returns false when paused field missing
func test_get_is_paused_returns_false_when_field_missing() -> void:
	var state: Dictionary = {"gameplay": {"entities": {}}}

	var is_paused: bool = U_GameplaySelectors.get_is_paused(state)

	assert_false(is_paused, "Should return false when paused field missing (default)")

func test_is_touch_look_active_returns_true_when_enabled() -> void:
	var state: Dictionary = {"gameplay": {"touch_look_active": true, "entities": {}}}

	var is_active: bool = U_GameplaySelectors.is_touch_look_active(state)

	assert_true(is_active, "Should return true when touch_look_active is set")

func test_is_touch_look_active_returns_false_when_missing() -> void:
	var state: Dictionary = {"gameplay": {"entities": {}}}

	var is_active: bool = U_GameplaySelectors.is_touch_look_active(state)

	assert_false(is_active, "Should default to false when touch_look_active is missing")

## Test selectors are pure functions (same input = same output)
func test_selectors_are_pure_functions() -> void:
	var state: Dictionary = {"gameplay": {"paused": true, "entities": {}}}

	var result1: bool = U_GameplaySelectors.get_is_paused(state)
	var result2: bool = U_GameplaySelectors.get_is_paused(state)

	assert_eq(result1, result2, "Selector should return same result for same input (pure function)")

## Test selectors do not mutate state
func test_selectors_do_not_mutate_state() -> void:
	var original_state: Dictionary = {"gameplay": {"paused": false, "entities": {}}}
	var state_copy: Dictionary = original_state.duplicate(true)

	var _result: bool = U_GameplaySelectors.get_is_paused(original_state)

	assert_eq(original_state, state_copy, "Selector should not mutate state")

## Phase 16.5: Mock selector tests removed
## Tests for entity selectors are in test_entity_coordination.gd