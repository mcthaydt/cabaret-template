extends GutTest

## Tests for GameplaySelectors derived state computation

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")

func before_each() -> void:
	StateStoreEventBus.reset()

func after_each() -> void:
	StateStoreEventBus.reset()

## Test get_is_player_alive returns false when health is zero
func test_get_is_player_alive_returns_false_when_health_zero() -> void:
	var gameplay_state: Dictionary = {"health": 0, "score": 100, "level": 1, "paused": false}
	
	var is_alive: bool = GameplaySelectors.get_is_player_alive(gameplay_state)
	
	assert_false(is_alive, "Player should not be alive when health is 0")

## Test get_is_player_alive returns true when health is positive
func test_get_is_player_alive_returns_true_when_health_positive() -> void:
	var gameplay_state: Dictionary = {"health": 50, "score": 100, "level": 1, "paused": false}
	
	var is_alive: bool = GameplaySelectors.get_is_player_alive(gameplay_state)
	
	assert_true(is_alive, "Player should be alive when health > 0")

## Test get_is_game_over computes from objectives (or health if no objectives)
func test_get_is_game_over_computes_from_objectives() -> void:
	# Test case 1: No objectives, health > 0 = not game over
	var state1: Dictionary = {"health": 50, "score": 100, "level": 1, "paused": false}
	var is_game_over1: bool = GameplaySelectors.get_is_game_over(state1)
	assert_false(is_game_over1, "Game should not be over when health > 0 and no objectives")
	
	# Test case 2: No objectives, health = 0 = game over
	var state2: Dictionary = {"health": 0, "score": 100, "level": 1, "paused": false}
	var is_game_over2: bool = GameplaySelectors.get_is_game_over(state2)
	assert_true(is_game_over2, "Game should be over when health = 0")
	
	# Test case 3: With objectives, check game_over field
	var state3: Dictionary = {"health": 50, "score": 100, "level": 1, "paused": false, "game_over": true}
	var is_game_over3: bool = GameplaySelectors.get_is_game_over(state3)
	assert_true(is_game_over3, "Game should be over when game_over flag is true")

## Test get_completion_percentage computes from objectives
func test_get_completion_percentage_computes_from_objectives() -> void:
	# Test case 1: No objectives data = 0% completion
	var state1: Dictionary = {"health": 50, "score": 100, "level": 1, "paused": false}
	var completion1: float = GameplaySelectors.get_completion_percentage(state1)
	assert_eq(completion1, 0.0, "Completion should be 0% when no objectives data")
	
	# Test case 2: With objectives data (simplified: level/max_levels)
	var state2: Dictionary = {"health": 50, "score": 100, "level": 3, "paused": false, "max_levels": 10}
	var completion2: float = GameplaySelectors.get_completion_percentage(state2)
	assert_almost_eq(completion2, 0.3, 0.01, "Completion should be ~30% (level 3 of 10)")
	
	# Test case 3: Completed all levels
	var state3: Dictionary = {"health": 50, "score": 100, "level": 10, "paused": false, "max_levels": 10}
	var completion3: float = GameplaySelectors.get_completion_percentage(state3)
	assert_eq(completion3, 1.0, "Completion should be 100% when all levels done")

## Test selectors are pure functions (same input = same output)
func test_selectors_are_pure_functions() -> void:
	var state: Dictionary = {"health": 75, "score": 500, "level": 2, "paused": false}
	
	var result1: bool = GameplaySelectors.get_is_player_alive(state)
	var result2: bool = GameplaySelectors.get_is_player_alive(state)
	
	assert_eq(result1, result2, "Selector should return same result for same input (pure function)")

## Test selectors do not mutate state
func test_selectors_do_not_mutate_state() -> void:
	var original_state: Dictionary = {"health": 75, "score": 500, "level": 2, "paused": false}
	var state_copy: Dictionary = original_state.duplicate(true)
	
	var _result: bool = GameplaySelectors.get_is_player_alive(original_state)
	
	assert_eq(original_state, state_copy, "Selector should not mutate state")
