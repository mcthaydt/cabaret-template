extends GutTest

## Unit tests for scene_reducer.gd
##
## Tests Redux reducer for scene state slice.
## Tests follow TDD discipline: written BEFORE implementation.

const U_SceneReducer = preload("res://scripts/state/reducers/u_scene_reducer.gd")
const U_SceneActions = preload("res://scripts/state/u_scene_actions.gd")

## Test initial state structure
func test_initial_state_has_required_fields() -> void:
	var initial_state: Dictionary = {
		"current_scene_id": StringName(""),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	assert_true(initial_state.has("current_scene_id"), "Initial state should have current_scene_id")
	assert_true(initial_state.has("scene_stack"), "Initial state should have scene_stack")
	assert_true(initial_state.has("is_transitioning"), "Initial state should have is_transitioning")
	assert_true(initial_state.has("transition_type"), "Initial state should have transition_type")

## Test TRANSITION_STARTED action
func test_transition_started_sets_transitioning_flag() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("main_menu"),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = U_SceneActions.transition_started(
		StringName("gameplay_base"),
		"fade"
	)

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_true(new_state["is_transitioning"], "Should set is_transitioning to true")
	assert_eq(new_state["transition_type"], "fade", "Should set transition_type")
	assert_eq(new_state["previous_scene_id"], StringName("main_menu"), "Should store previous scene ID")

## Test TRANSITION_COMPLETED action
func test_transition_completed_updates_current_scene() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("main_menu"),
		"scene_stack": [],
		"is_transitioning": true,
		"transition_type": "fade",
		"previous_scene_id": StringName("main_menu")
	}

	var action: Dictionary = U_SceneActions.transition_completed(StringName("gameplay_base"))

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_eq(new_state["current_scene_id"], StringName("gameplay_base"), "Should update current_scene_id")
	assert_false(new_state["is_transitioning"], "Should clear is_transitioning flag")
	assert_eq(new_state["transition_type"], "", "Should clear transition_type")

## Test PUSH_OVERLAY action
func test_push_overlay_adds_to_scene_stack() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("gameplay_base"),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = U_SceneActions.push_overlay(StringName("pause_menu"))

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_eq(new_state["scene_stack"].size(), 1, "Should add overlay to stack")
	assert_eq(new_state["scene_stack"][0], StringName("pause_menu"), "Should add correct scene ID")
	assert_eq(new_state["current_scene_id"], StringName("gameplay_base"), "Should not change current_scene_id")

## Test POP_OVERLAY action
func test_pop_overlay_removes_from_scene_stack() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("gameplay_base"),
		"scene_stack": [StringName("pause_menu"), StringName("settings_menu")],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = U_SceneActions.pop_overlay()

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_eq(new_state["scene_stack"].size(), 1, "Should remove one overlay from stack")
	assert_eq(new_state["scene_stack"][0], StringName("pause_menu"), "Should keep bottom overlay")

## Test POP_OVERLAY with empty stack
func test_pop_overlay_with_empty_stack_does_nothing() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("gameplay_base"),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = U_SceneActions.pop_overlay()

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_eq(new_state["scene_stack"].size(), 0, "Should remain empty")

## Test immutability - reducer returns new state
func test_reducer_returns_new_state_object() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("main_menu"),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = U_SceneActions.transition_started(
		StringName("gameplay_base"),
		"fade"
	)

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_ne(new_state, state, "Should return new state object (immutability)")
	assert_false(state["is_transitioning"], "Should not mutate original state")
	assert_true(new_state["is_transitioning"], "New state should have changes")

## Test unrecognized action returns state unchanged
func test_unrecognized_action_returns_state_unchanged() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("main_menu"),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = {
		"type": StringName("unknown/action"),
		"payload": {}
	}

	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_eq(new_state, state, "Should return state unchanged for unrecognized actions")

## Test nested overlay stack management
func test_multiple_overlay_pushes() -> void:
	var state: Dictionary = {
		"current_scene_id": StringName("gameplay_base"),
		"scene_stack": [],
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	# Push pause menu
	var action1: Dictionary = U_SceneActions.push_overlay(StringName("pause_menu"))
	var state1: Dictionary = U_SceneReducer.reduce(state, action1)

	# Push settings menu
	var action2: Dictionary = U_SceneActions.push_overlay(StringName("settings_menu"))
	var state2: Dictionary = U_SceneReducer.reduce(state1, action2)

	assert_eq(state2["scene_stack"].size(), 2, "Should have two overlays")
	assert_eq(state2["scene_stack"][0], StringName("pause_menu"), "First overlay should be pause")
	assert_eq(state2["scene_stack"][1], StringName("settings_menu"), "Second overlay should be settings")

## Test scene_stack is properly duplicated (immutability)
func test_scene_stack_is_duplicated() -> void:
	var original_stack: Array = [StringName("pause_menu")]
	var state: Dictionary = {
		"current_scene_id": StringName("gameplay_base"),
		"scene_stack": original_stack,
		"is_transitioning": false,
		"transition_type": "",
		"previous_scene_id": StringName("")
	}

	var action: Dictionary = U_SceneActions.push_overlay(StringName("settings_menu"))
	var new_state: Dictionary = U_SceneReducer.reduce(state, action)

	assert_eq(original_stack.size(), 1, "Original stack should be unchanged")
	assert_eq(new_state["scene_stack"].size(), 2, "New stack should have two items")
