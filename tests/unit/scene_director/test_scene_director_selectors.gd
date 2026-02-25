extends GutTest

const SCENE_DIRECTOR_SELECTORS := preload("res://scripts/state/selectors/u_scene_director_selectors.gd")

func test_get_active_directive_id_returns_directive_id() -> void:
	var state := _make_state(StringName("dir_intro"), 1, "running")
	var directive_id: StringName = SCENE_DIRECTOR_SELECTORS.get_active_directive_id(state)
	assert_eq(directive_id, StringName("dir_intro"))

func test_get_current_beat_index_returns_index() -> void:
	var state := _make_state(StringName("dir_intro"), 3, "running")
	var index: int = SCENE_DIRECTOR_SELECTORS.get_current_beat_index(state)
	assert_eq(index, 3)

func test_is_running_true_only_when_state_is_running() -> void:
	var running_state := _make_state(StringName("dir_intro"), 1, "running")
	var idle_state := _make_state(StringName("dir_intro"), -1, "idle")
	var completed_state := _make_state(StringName("dir_intro"), 4, "completed")

	assert_true(SCENE_DIRECTOR_SELECTORS.is_running(running_state))
	assert_false(SCENE_DIRECTOR_SELECTORS.is_running(idle_state))
	assert_false(SCENE_DIRECTOR_SELECTORS.is_running(completed_state))

func test_get_director_state_returns_state_string() -> void:
	var state := _make_state(StringName("dir_intro"), 1, "completed")
	var director_state: String = SCENE_DIRECTOR_SELECTORS.get_director_state(state)
	assert_eq(director_state, "completed")

func test_selectors_return_safe_defaults_on_missing_state() -> void:
	var missing_state := {}

	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_active_directive_id(missing_state),
		StringName("")
	)
	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_current_beat_index(missing_state),
		-1
	)
	assert_false(
		SCENE_DIRECTOR_SELECTORS.is_running(missing_state),
		"Missing state should not be running"
	)
	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_director_state(missing_state),
		"idle"
	)

func _make_state(active_directive_id: StringName, beat_index: int, director_state: String) -> Dictionary:
	return {
		"scene_director": {
			"active_directive_id": active_directive_id,
			"current_beat_index": beat_index,
			"state": director_state,
		}
	}
