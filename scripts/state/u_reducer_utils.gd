@icon("res://editor_icons/utility.svg")
extends RefCounted
class_name U_ReducerUtils

static func combine_reducers(reducers: Dictionary) -> Callable:
	var slice_names: Array = reducers.keys()
	return func(state: Dictionary, action: Dictionary) -> Dictionary:
		var previous_state: Dictionary = {}
		if typeof(state) == TYPE_DICTIONARY:
			previous_state = state

		var next_state: Dictionary = {}
		for slice_name in slice_names:
			var reducer = reducers[slice_name]
			var slice_state: Variant
			if previous_state.has(slice_name):
				slice_state = previous_state[slice_name]
			else:
				slice_state = _get_initial_state(reducer)
			next_state[slice_name] = reducer.reduce(slice_state, action)
		return next_state

static func collect_initial_state(reducers: Dictionary) -> Dictionary:
	var initial_state: Dictionary = {}
	for slice_name in reducers.keys():
		var reducer = reducers[slice_name]
		initial_state[slice_name] = _get_initial_state(reducer)
	return initial_state

static func _get_initial_state(reducer) -> Dictionary:
	if reducer.has_method("get_initial_state"):
		var initial: Variant = reducer.get_initial_state()
		if typeof(initial) == TYPE_DICTIONARY:
			return initial.duplicate(true)
	return {}
