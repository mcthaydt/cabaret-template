extends BaseTest

const U_ReducerUtils: Script = preload("res://scripts/state/u_reducer_utils.gd")
const U_ActionUtils: Script = preload("res://scripts/state/u_action_utils.gd")

class CounterReducer:
	static func get_initial_state() -> Dictionary:
		return {"value": 0}

	static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
		var updated := state.duplicate(true)
		match action.get("type", StringName("")):
			StringName("counter/increment"):
				updated["value"] += int(action.get("payload", 1))
			StringName("counter/reset"):
				updated["value"] = 0
		return updated

class FlagReducer:
	static func get_initial_state() -> Dictionary:
		return {"enabled": false}

	static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
		var updated := state.duplicate(true)
		if action.get("type", StringName("")) == StringName("flag/set"):
			updated["enabled"] = bool(action.get("payload", false))
		return updated

func test_combine_reducers_returns_root_callable() -> void:
	var reducers: Dictionary = {
		StringName("counter"): CounterReducer,
		StringName("flag"): FlagReducer,
	}

	var root: Callable = U_ReducerUtils.combine_reducers(reducers)

	var initial_state: Dictionary = {
		StringName("counter"): CounterReducer.get_initial_state(),
		StringName("flag"): FlagReducer.get_initial_state(),
	}

	var action: Dictionary = U_ActionUtils.create_action("counter/increment", 2)
	var next_state: Dictionary = root.call(initial_state, action)

	assert_eq(next_state["counter"]["value"], 2)
	assert_eq(next_state["flag"]["enabled"], false)

	# Ensure original state was not mutated.
	assert_eq(initial_state["counter"]["value"], 0)

func test_combine_reducers_fills_missing_state_with_initial_values() -> void:
	var reducers: Dictionary = {
		StringName("counter"): CounterReducer,
		StringName("flag"): FlagReducer,
	}

	var root: Callable = U_ReducerUtils.combine_reducers(reducers)

	var action: Dictionary = U_ActionUtils.create_action("flag/set", true)
	var next_state: Dictionary = root.call({}, action)

	assert_eq(next_state["counter"]["value"], 0)
	assert_true(next_state["flag"]["enabled"])
