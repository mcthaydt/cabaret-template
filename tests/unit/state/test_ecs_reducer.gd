extends BaseTest

const EcsReducer := preload("res://scripts/state/reducers/ecs_reducer.gd")

func test_ecs_reducer_returns_initial_state_on_init() -> void:
	var result: Dictionary = EcsReducer.reduce({}, {"type": StringName("@@INIT")})
	assert_eq(result["components"], {})
	assert_eq(result["systems"], {})
	assert_false(result["dirty"])

func test_ecs_reducer_tracks_component_registration() -> void:
	var state: Dictionary = EcsReducer.get_initial_state()
	var payload: Dictionary = {
		"id": 1,
		"component_type": StringName("C_MovementComponent"),
	}
	var action: Dictionary = {
		"type": StringName("ecs/register_component"),
		"payload": payload,
	}
	var next_state: Dictionary = EcsReducer.reduce(state, action)
	assert_true(next_state["components"].has(1))
	assert_true(next_state["dirty"])
	assert_false(state["components"].has(1))

func test_ecs_reducer_can_clear_dirty_flag() -> void:
	var state: Dictionary = {
		"components": {1: {"id": 1}},
		"systems": {},
		"dirty": true,
	}
	var action: Dictionary = {
		"type": StringName("ecs/clear_dirty"),
	}
	var next_state: Dictionary = EcsReducer.reduce(state, action)
	assert_false(next_state["dirty"])
