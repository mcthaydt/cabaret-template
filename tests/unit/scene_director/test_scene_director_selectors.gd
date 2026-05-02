extends GutTest

const SCENE_DIRECTOR_SELECTORS := preload("res://scripts/core/state/selectors/u_scene_director_selectors.gd")

func test_get_active_directive_id_returns_directive_id() -> void:
	var state := _make_state(StringName("dir_intro"), 1, "running")
	var directive_id: StringName = SCENE_DIRECTOR_SELECTORS.get_active_directive_id(state)
	assert_eq(directive_id, StringName("dir_intro"))

func test_get_current_beat_index_returns_index() -> void:
	var state := _make_state(StringName("dir_intro"), 3, "running")
	var index: int = SCENE_DIRECTOR_SELECTORS.get_current_beat_index(state)
	assert_eq(index, 3)

func test_parallel_selectors_return_lane_ids_and_status() -> void:
	var state := _make_state(StringName("dir_intro"), 3, "running")
	state["scene_director"]["parallel_lane_ids"] = [StringName("lane_a"), StringName("lane_b")]

	var lane_ids: Array[StringName] = SCENE_DIRECTOR_SELECTORS.get_parallel_lane_ids(state)
	assert_eq(lane_ids, [StringName("lane_a"), StringName("lane_b")])
	assert_true(SCENE_DIRECTOR_SELECTORS.is_parallel(state))
	state["scene_director"]["parallel_lane_ids"] = []
	assert_false(SCENE_DIRECTOR_SELECTORS.is_parallel(state))

func test_observability_selectors_return_current_and_active_beats() -> void:
	var state := _make_state(StringName("dir_intro"), 2, "running")
	state["scene_director"]["current_beat_id"] = StringName("beat_join")
	state["scene_director"]["active_beat_ids"] = [StringName("beat_join"), StringName("lane_a")]

	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_current_beat_id(state),
		StringName("beat_join")
	)
	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_active_beat_ids(state),
		[StringName("beat_join"), StringName("lane_a")]
	)

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
	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_current_beat_id(missing_state),
		StringName("")
	)
	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_active_beat_ids(missing_state),
		[]
	)
	assert_eq(
		SCENE_DIRECTOR_SELECTORS.get_parallel_lane_ids(missing_state),
		[]
	)
	assert_false(
		SCENE_DIRECTOR_SELECTORS.is_parallel(missing_state),
		"Missing state should not be parallel"
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
			"current_beat_id": StringName(""),
			"active_beat_ids": [],
			"parallel_lane_ids": [],
			"state": director_state,
		}
	}
