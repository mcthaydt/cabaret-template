extends GutTest

## Tests for BootReducer pure functions

const U_StateEventBus := preload("res://scripts/state/u_state_event_bus.gd")
const StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const U_BootActions := preload("res://scripts/state/actions/u_boot_actions.gd")
const BootReducer := preload("res://scripts/state/reducers/u_boot_reducer.gd")

func before_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

func after_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

## T330: Test boot slice initializes with loading 0 percent
func test_boot_slice_initializes_with_loading_0_percent() -> void:
	var initial_state := RS_BootInitialState.new()
	var state_dict: Dictionary = initial_state.to_dictionary()
	
	assert_eq(state_dict.get("loading_progress"), 0.0, "Initial loading progress should be 0.0")
	assert_eq(state_dict.get("is_ready"), false, "Initial is_ready should be false")

## T331: Test update loading progress updates percentage
func test_update_loading_progress_updates_percentage() -> void:
	var state: Dictionary = {"loading_progress": 0.0, "phase": "loading", "error_message": "", "is_ready": false}
	var action: Dictionary = U_BootActions.update_loading_progress(0.5)
	
	var result: Dictionary = BootReducer.reduce(state, action)
	
	assert_eq(result["loading_progress"], 0.5, "Loading progress should update to 0.5")
	assert_eq(state["loading_progress"], 0.0, "Original state should remain unchanged")

## T332: Test boot error sets error state and message
func test_boot_error_sets_error_state_and_message() -> void:
	var state: Dictionary = {"loading_progress": 0.3, "phase": "loading", "error_message": "", "is_ready": false}
	var action: Dictionary = U_BootActions.boot_error("Failed to load assets")
	
	var result: Dictionary = BootReducer.reduce(state, action)
	
	assert_eq(result["phase"], "error", "Phase should be set to error")
	assert_eq(result["error_message"], "Failed to load assets", "Error message should be stored")
	assert_eq(state["phase"], "loading", "Original state phase should remain unchanged")

## T333: Test boot complete transitions to ready state
func test_boot_complete_transitions_to_ready_state() -> void:
	var state: Dictionary = {"loading_progress": 1.0, "phase": "loading", "error_message": "", "is_ready": false}
	var action: Dictionary = U_BootActions.boot_complete()
	
	var result: Dictionary = BootReducer.reduce(state, action)
	
	assert_eq(result["is_ready"], true, "is_ready should be set to true")
	assert_eq(result["phase"], "ready", "Phase should be set to ready")
	assert_eq(state["is_ready"], false, "Original state is_ready should remain unchanged")

## Test reducer is pure function
func test_reducer_is_pure_function() -> void:
	var state: Dictionary = {"loading_progress": 0.5, "phase": "loading", "error_message": "", "is_ready": false}
	var action: Dictionary = U_BootActions.update_loading_progress(0.7)
	
	var result1: Dictionary = BootReducer.reduce(state, action)
	var result2: Dictionary = BootReducer.reduce(state, action)
	
	assert_eq(result1, result2, "Same inputs should produce same outputs (pure function)")

## Test reducer does not mutate original state
func test_reducer_does_not_mutate_original_state() -> void:
	var original_state: Dictionary = {"loading_progress": 0.0, "phase": "loading", "error_message": "", "is_ready": false}
	var action: Dictionary = U_BootActions.update_loading_progress(0.5)
	
	var _new_state: Dictionary = BootReducer.reduce(original_state, action)
	
	assert_eq(original_state["loading_progress"], 0.0, "Original loading_progress should remain unchanged")
	assert_eq(original_state["phase"], "loading", "Original phase should remain unchanged")

## Test unknown action returns state unchanged
func test_unknown_action_returns_state_unchanged() -> void:
	var state: Dictionary = {"loading_progress": 0.5, "phase": "loading", "error_message": "", "is_ready": false}
	var unknown_action: Dictionary = {"type": StringName("unknown/action"), "payload": null}
	
	var result: Dictionary = BootReducer.reduce(state, unknown_action)
	
	assert_eq(result, state, "Unknown action should return state unchanged")
