extends BaseTest

const GameReducer := preload("res://scripts/state/reducers/game_reducer.gd")

func test_game_reducer_returns_initial_state_on_init() -> void:
	var action: Dictionary = {
		"type": StringName("@@INIT"),
	}
	var result: Dictionary = GameReducer.reduce({}, action)
	assert_true(result.has("score"))
	assert_eq(int(result["score"]), 0)
	assert_eq(int(result["level"]), 1)
	assert_true(result.has("unlocks"))
	assert_eq(result["unlocks"], [])

func test_game_reducer_handles_add_score() -> void:
	var state: Dictionary = {
		"score": 10,
		"level": 1,
		"unlocks": [],
	}
	var action: Dictionary = {
		"type": StringName("game/add_score"),
		"payload": 5,
	}
	var next_state: Dictionary = GameReducer.reduce(state, action)
	assert_eq(int(next_state["score"]), 15)
	assert_eq(int(state["score"]), 10)

func test_game_reducer_handles_unlock_action_without_duplicates() -> void:
	var state: Dictionary = {
		"score": 0,
		"level": 2,
		"unlocks": ["dash"],
	}
	var action: Dictionary = {
		"type": StringName("game/unlock"),
		"payload": "wall_jump",
	}
	var next_state: Dictionary = GameReducer.reduce(state, action)
	assert_true(next_state["unlocks"].has("wall_jump"))
	assert_true(next_state["unlocks"].has("dash"))
	assert_ne(next_state, state)
