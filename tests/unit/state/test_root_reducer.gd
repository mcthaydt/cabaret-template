extends BaseTest

const RootReducer := preload("res://scripts/state/reducers/root_reducer.gd")

func test_root_reducer_initializes_all_slices() -> void:
	var initial: Dictionary = RootReducer.get_initial_state()
	assert_true(initial.has(StringName("game")))
	assert_true(initial.has(StringName("ui")))
	assert_true(initial.has(StringName("ecs")))
	assert_true(initial.has(StringName("session")))

func test_root_reducer_updates_only_target_slice() -> void:
	var state: Dictionary = RootReducer.get_initial_state()
	var action: Dictionary = {
		"type": StringName("game/add_score"),
		"payload": 3,
	}
	var next_state: Dictionary = RootReducer.reduce(state, action)
	assert_eq(int(state[StringName("game")]["score"]), 0)
	assert_eq(int(next_state[StringName("game")]["score"]), 3)
	assert_eq(next_state[StringName("ui")], state[StringName("ui")])
