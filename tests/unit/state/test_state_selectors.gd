extends GutTest

## Tests for GameplaySelectors derived state computation

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")

func before_each() -> void:
	StateStoreEventBus.reset()

func after_each() -> void:
	StateStoreEventBus.reset()

## Test get_is_paused returns true when paused
func test_get_is_paused_returns_true_when_paused() -> void:
	var gameplay_state: Dictionary = {"paused": true, "entities": {}}
	
	var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	assert_true(is_paused, "Should return true when paused")

## Test get_is_paused returns false when not paused
func test_get_is_paused_returns_false_when_not_paused() -> void:
	var gameplay_state: Dictionary = {"paused": false, "entities": {}}
	
	var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	assert_false(is_paused, "Should return false when not paused")

## Test get_is_paused returns false when paused field missing
func test_get_is_paused_returns_false_when_field_missing() -> void:
	var gameplay_state: Dictionary = {"entities": {}}
	
	var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	assert_false(is_paused, "Should return false when paused field missing (default)")

## Test selectors are pure functions (same input = same output)
func test_selectors_are_pure_functions() -> void:
	var state: Dictionary = {"paused": true, "entities": {}}
	
	var result1: bool = GameplaySelectors.get_is_paused(state)
	var result2: bool = GameplaySelectors.get_is_paused(state)
	
	assert_eq(result1, result2, "Selector should return same result for same input (pure function)")

## Test selectors do not mutate state
func test_selectors_do_not_mutate_state() -> void:
	var original_state: Dictionary = {"paused": false, "entities": {}}
	var state_copy: Dictionary = original_state.duplicate(true)
	
	var _result: bool = GameplaySelectors.get_is_paused(original_state)
	
	assert_eq(original_state, state_copy, "Selector should not mutate state")

## Phase 16.5: Mock selector tests removed
## Tests for entity selectors are in test_entity_coordination.gd
