extends BaseTest

const UiReducer := preload("res://scripts/state/reducers/ui_reducer.gd")

func test_ui_reducer_returns_initial_state_on_init() -> void:
	var result: Dictionary = UiReducer.reduce({}, {"type": StringName("@@INIT")})
	assert_eq(result["active_menu"], StringName(""))
	assert_eq(result["history"], [])
	assert_eq(result["settings"], {})

func test_ui_reducer_handles_open_and_close_menu() -> void:
	var state: Dictionary = UiReducer.get_initial_state()
	var open_action: Dictionary = {
		"type": StringName("ui/open_menu"),
		"payload": StringName("pause"),
	}
	var opened: Dictionary = UiReducer.reduce(state, open_action)
	assert_eq(opened["active_menu"], StringName("pause"))
	assert_eq(opened["history"].size(), 1)

	var close_action: Dictionary = {
		"type": StringName("ui/close_menu"),
	}
	var closed: Dictionary = UiReducer.reduce(opened, close_action)
	assert_eq(closed["active_menu"], StringName(""))
	assert_eq(closed["history"].size(), 1)

func test_ui_reducer_sets_setting_without_mutating_original() -> void:
	var state: Dictionary = UiReducer.get_initial_state()
	var payload: Dictionary = {
		"key": "music_volume",
		"value": 0.5,
	}
	var action: Dictionary = {
		"type": StringName("ui/set_setting"),
		"payload": payload,
	}
	var next_state: Dictionary = UiReducer.reduce(state, action)
	assert_eq(float(next_state["settings"]["music_volume"]), 0.5)
	assert_false(state["settings"].has("music_volume"))
