extends BaseTest

const STATE_MANAGER := preload("res://scripts/managers/m_state_manager.gd")
const GameReducer := preload("res://scripts/state/reducers/game_reducer.gd")
const UiReducer := preload("res://scripts/state/reducers/ui_reducer.gd")
const EcsReducer := preload("res://scripts/state/reducers/ecs_reducer.gd")
const SessionReducer := preload("res://scripts/state/reducers/session_reducer.gd")
const GameActions := preload("res://scripts/state/actions/game_actions.gd")
const UiActions := preload("res://scripts/state/actions/ui_actions.gd")
const SessionActions := preload("res://scripts/state/actions/session_actions.gd")

func test_state_store_integration_save_and_load_round_trip() -> void:
	var store: M_StateManager = STATE_MANAGER.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	store.register_reducer(GameReducer)
	store.register_reducer(UiReducer)
	store.register_reducer(EcsReducer)
	store.register_reducer(SessionReducer)

	store.dispatch(GameActions.add_score(25))
	store.dispatch(UiActions.open_menu("pause"))
	store.dispatch(SessionActions.set_slot(3))
	store.dispatch(SessionActions.set_flag("tutorial_complete", true))

	var path: String = "user://state_store_integration.json"
	var save_err: Error = store.save_state(path)
	assert_eq(save_err, OK)

	store.dispatch(GameActions.set_score(0))
	store.dispatch(UiActions.close_menu())
	store.dispatch(SessionActions.set_slot(0))
	store.dispatch(SessionActions.clear_flag("tutorial_complete"))

	var load_err: Error = store.load_state(path)
	assert_eq(load_err, OK)

	var state: Dictionary = store.get_state()
	assert_eq(int(state[StringName("game")]["score"]), 25)
	assert_eq(state[StringName("ui")]["active_menu"], StringName(""))
	assert_eq(int(state[StringName("session")]["slot"]), 3)
	assert_true(state[StringName("session")]["flags"].has(StringName("tutorial_complete")))

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
