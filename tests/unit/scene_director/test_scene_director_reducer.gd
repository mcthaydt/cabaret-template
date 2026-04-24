extends GutTest

const SCENE_DIRECTOR_ACTIONS := preload("res://scripts/core/state/actions/u_scene_director_actions.gd")
const SCENE_DIRECTOR_REDUCER := preload("res://scripts/core/state/reducers/u_scene_director_reducer.gd")
const OBJECTIVES_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_objectives_initial_state.gd")
const SCENE_DIRECTOR_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_scene_director_initial_state.gd")

func test_start_directive_sets_running_state_and_index_zero() -> void:
	var state := _base_state()
	var action := SCENE_DIRECTOR_ACTIONS.start_directive(StringName("dir_intro"))
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(state, action)

	assert_eq(reduced.get("active_directive_id"), StringName("dir_intro"))
	assert_eq(reduced.get("current_beat_index"), 0)
	assert_eq(reduced.get("current_beat_id"), StringName(""))
	assert_eq(reduced.get("active_beat_ids"), [])
	assert_eq(reduced.get("parallel_lane_ids"), [])
	assert_eq(reduced.get("state"), "running")

func test_advance_beat_increments_index_by_one() -> void:
	var running_state := {
		"active_directive_id": StringName("dir_intro"),
		"current_beat_index": 0,
		"state": "running",
	}

	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		running_state,
		SCENE_DIRECTOR_ACTIONS.advance_beat()
	)
	assert_eq(reduced.get("current_beat_index"), 1)

func test_complete_directive_sets_completed_state() -> void:
	var running_state := {
		"active_directive_id": StringName("dir_intro"),
		"current_beat_index": 2,
		"current_beat_id": StringName("beat_a"),
		"active_beat_ids": [StringName("beat_a")],
		"parallel_lane_ids": [StringName("lane_a")],
		"state": "running",
	}
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		running_state,
		SCENE_DIRECTOR_ACTIONS.complete_directive()
	)

	assert_eq(reduced.get("state"), "completed")
	assert_eq(reduced.get("active_directive_id"), StringName("dir_intro"))
	assert_eq(reduced.get("parallel_lane_ids"), [])
	assert_eq(reduced.get("active_beat_ids"), [])

func test_reset_returns_idle_defaults() -> void:
	var running_state := {
		"active_directive_id": StringName("dir_intro"),
		"current_beat_index": 4,
		"current_beat_id": StringName("beat_join"),
		"active_beat_ids": [StringName("beat_join")],
		"parallel_lane_ids": [StringName("lane_a"), StringName("lane_b")],
		"state": "running",
	}

	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		running_state,
		SCENE_DIRECTOR_ACTIONS.reset()
	)

	assert_eq(reduced.get("active_directive_id"), StringName(""))
	assert_eq(reduced.get("current_beat_index"), -1)
	assert_eq(reduced.get("current_beat_id"), StringName(""))
	assert_eq(reduced.get("active_beat_ids"), [])
	assert_eq(reduced.get("parallel_lane_ids"), [])
	assert_eq(reduced.get("state"), "idle")

func test_set_beat_index_sets_arbitrary_index() -> void:
	var state := _base_state()
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		state,
		SCENE_DIRECTOR_ACTIONS.set_beat_index(7)
	)
	assert_eq(reduced.get("current_beat_index"), 7)

func test_start_parallel_stores_lane_ids() -> void:
	var state := _base_state()
	var lane_ids: Array[StringName] = [StringName("lane_a"), StringName("lane_b")]
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		state,
		SCENE_DIRECTOR_ACTIONS.start_parallel(lane_ids)
	)
	assert_eq(reduced.get("parallel_lane_ids"), lane_ids)

func test_complete_parallel_clears_lane_ids() -> void:
	var state := _base_state()
	state["parallel_lane_ids"] = [StringName("lane_a")]
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		state,
		SCENE_DIRECTOR_ACTIONS.complete_parallel()
	)
	assert_eq(reduced.get("parallel_lane_ids"), [])

func test_reducer_is_immutable() -> void:
	var state := _base_state()
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		state,
		SCENE_DIRECTOR_ACTIONS.start_directive(StringName("dir_intro"))
	)

	assert_ne(state, reduced, "Reducer should return a new dictionary")
	assert_eq(state.get("state"), "idle", "Original state should remain unchanged")

func test_unknown_action_returns_state_unchanged() -> void:
	var state := _base_state()
	var reduced: Dictionary = SCENE_DIRECTOR_REDUCER.reduce(
		state,
		{"type": StringName("scene_director/unknown")}
	)
	assert_eq(reduced, state, "Unknown action should return original state")

func test_state_store_registers_objectives_and_transient_scene_director_slices() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.debug_initial_state = RS_DebugInitialState.new()
	store.vfx_initial_state = RS_VFXInitialState.new()
	store.audio_initial_state = RS_AudioInitialState.new()
	store.display_initial_state = RS_DisplayInitialState.new()
	store.localization_initial_state = RS_LocalizationInitialState.new()
	store.time_initial_state = RS_TimeInitialState.new()
	store.objectives_initial_state = OBJECTIVES_INITIAL_STATE.new()
	store.scene_director_initial_state = SCENE_DIRECTOR_INITIAL_STATE.new()

	add_child(store)
	autofree(store)
	await get_tree().process_frame

	var objectives_slice: Dictionary = store.get_slice(StringName("objectives"))
	var director_slice: Dictionary = store.get_slice(StringName("scene_director"))
	var persistable: Dictionary = store.get_persistable_state()

	assert_true(persistable.has("objectives"), "Objectives slice should be persisted")
	assert_false(persistable.has("scene_director"), "Scene director slice should be transient")
	assert_eq(
		objectives_slice.get("active_set_id"),
		StringName(""),
		"Objectives slice should initialize from initial-state resource"
	)
	assert_eq(
		director_slice.get("state"),
		"idle",
		"Scene director slice should initialize with idle state"
	)

func _base_state() -> Dictionary:
	return {
		"active_directive_id": StringName(""),
		"current_beat_index": -1,
		"current_beat_id": StringName(""),
		"active_beat_ids": [],
		"parallel_lane_ids": [],
		"state": "idle",
	}
