@icon("res://editor_icons/reducer.svg")
extends RefCounted
class_name RootReducer

const U_REDUCER_UTILS := preload("res://scripts/state/u_reducer_utils.gd")
const GAME_REDUCER := preload("res://scripts/state/reducers/game_reducer.gd")
const UI_REDUCER := preload("res://scripts/state/reducers/ui_reducer.gd")
const ECS_REDUCER := preload("res://scripts/state/reducers/ecs_reducer.gd")
const SESSION_REDUCER := preload("res://scripts/state/reducers/session_reducer.gd")

static var _combined: Callable = Callable()

static func get_initial_state() -> Dictionary:
	return U_REDUCER_UTILS.collect_initial_state(_get_reducers())

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	if _combined.is_null():
		_combined = U_REDUCER_UTILS.combine_reducers(_get_reducers())
	return _combined.call(state, action)

static func _get_reducers() -> Dictionary:
	return {
		GAME_REDUCER.get_slice_name(): GAME_REDUCER,
		UI_REDUCER.get_slice_name(): UI_REDUCER,
		ECS_REDUCER.get_slice_name(): ECS_REDUCER,
		SESSION_REDUCER.get_slice_name(): SESSION_REDUCER,
	}
