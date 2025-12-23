extends GutTest
# Test suite for save Redux slice (reducer, actions, selectors)
# Tests state transitions for save/load operations

const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_SaveReducer := preload("res://scripts/state/reducers/u_save_reducer.gd")
const RS_SaveInitialState := preload("res://scripts/state/resources/rs_save_initial_state.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")


# ==============================================================================
# Initial State Tests
# ==============================================================================

func test_initial_state_structure() -> void:
	var initial := RS_SaveInitialState.new()
	var state := initial.to_dictionary()

	assert_true(state.has("is_saving"), "Should have is_saving field")
	assert_true(state.has("is_loading"), "Should have is_loading field")
	assert_true(state.has("last_save_slot"), "Should have last_save_slot field")
	assert_true(state.has("last_error"), "Should have last_error field")
	assert_false(state.get("is_saving"), "is_saving should default to false")
	assert_false(state.get("is_loading"), "is_loading should default to false")
	assert_eq(state.get("last_save_slot"), -1, "last_save_slot should default to -1")
	assert_eq(state.get("last_error"), "", "last_error should default to empty")


# ==============================================================================
# Save Operation Tests
# ==============================================================================

func test_save_started_sets_is_saving_true() -> void:
	var state := _make_state()
	var action := U_SaveActions.save_started(1)
	var reduced := U_SaveReducer.reduce(state, action)

	assert_true(reduced.get("is_saving"), "is_saving should be true")
	assert_eq(reduced.get("last_error"), "", "last_error should be cleared")
	assert_false(state.get("is_saving"), "Original state should remain unchanged")


func test_save_completed_sets_is_saving_false_and_updates_last_slot() -> void:
	var state := _make_state()
	state["is_saving"] = true

	var action := U_SaveActions.save_completed(2)
	var reduced := U_SaveReducer.reduce(state, action)

	assert_false(reduced.get("is_saving"), "is_saving should be false")
	assert_eq(reduced.get("last_save_slot"), 2, "last_save_slot should be updated")
	assert_eq(reduced.get("last_error"), "", "last_error should be empty")


func test_save_failed_sets_is_saving_false_and_sets_error() -> void:
	var state := _make_state()
	state["is_saving"] = true

	var action := U_SaveActions.save_failed(1, "Disk full")
	var reduced := U_SaveReducer.reduce(state, action)

	assert_false(reduced.get("is_saving"), "is_saving should be false")
	assert_eq(reduced.get("last_error"), "Disk full", "last_error should be set")
	assert_eq(reduced.get("last_save_slot"), -1, "last_save_slot should remain unchanged")


# ==============================================================================
# Load Operation Tests
# ==============================================================================

func test_load_started_sets_is_loading_true() -> void:
	var state := _make_state()
	var action := U_SaveActions.load_started(2)
	var reduced := U_SaveReducer.reduce(state, action)

	assert_true(reduced.get("is_loading"), "is_loading should be true")
	assert_eq(reduced.get("last_error"), "", "last_error should be cleared")
	assert_false(state.get("is_loading"), "Original state should remain unchanged")


func test_load_completed_sets_is_loading_false() -> void:
	var state := _make_state()
	state["is_loading"] = true

	var action := U_SaveActions.load_completed(1)
	var reduced := U_SaveReducer.reduce(state, action)

	assert_false(reduced.get("is_loading"), "is_loading should be false")
	assert_eq(reduced.get("last_error"), "", "last_error should be empty")


func test_load_failed_sets_is_loading_false_and_sets_error() -> void:
	var state := _make_state()
	state["is_loading"] = true

	var action := U_SaveActions.load_failed(3, "Corrupted save")
	var reduced := U_SaveReducer.reduce(state, action)

	assert_false(reduced.get("is_loading"), "is_loading should be false")
	assert_eq(reduced.get("last_error"), "Corrupted save", "last_error should be set")


# ==============================================================================
# Delete Operation Tests
# ==============================================================================

func test_delete_started_sets_is_deleting_true() -> void:
	var state := _make_state()
	var action := U_SaveActions.delete_started(2)
	var reduced := U_SaveReducer.reduce(state, action)

	assert_true(reduced.get("is_deleting"), "is_deleting should be true")
	assert_eq(reduced.get("last_error"), "", "last_error should be cleared")


func test_delete_completed_sets_is_deleting_false() -> void:
	var state := _make_state()
	state["is_deleting"] = true

	var action := U_SaveActions.delete_completed(2)
	var reduced := U_SaveReducer.reduce(state, action)

	assert_false(reduced.get("is_deleting"), "is_deleting should be false")
	assert_eq(reduced.get("last_error"), "", "last_error should be empty")


func test_delete_failed_sets_is_deleting_false_and_sets_error() -> void:
	var state := _make_state()
	state["is_deleting"] = true

	var action := U_SaveActions.delete_failed(0, "Cannot delete autosave")
	var reduced := U_SaveReducer.reduce(state, action)

	assert_false(reduced.get("is_deleting"), "is_deleting should be false")
	assert_eq(reduced.get("last_error"), "Cannot delete autosave", "last_error should be set")


# ==============================================================================
# UI Mode Tests
# ==============================================================================

func test_set_save_mode_updates_current_mode() -> void:
	var state := _make_state()
	var action := U_SaveActions.set_save_mode(0)  # SAVE mode
	var reduced := U_SaveReducer.reduce(state, action)

	assert_eq(reduced.get("current_mode"), 0, "current_mode should be updated")
	assert_eq(state.get("current_mode"), 1, "Original state should remain unchanged")


# ==============================================================================
# Immutability Tests
# ==============================================================================

func test_reducer_does_not_mutate_original_state() -> void:
	var state := _make_state()
	var original_is_saving: bool = state.get("is_saving")
	var original_last_slot: int = state.get("last_save_slot")

	var action := U_SaveActions.save_completed(3)
	var _reduced := U_SaveReducer.reduce(state, action)

	assert_eq(state.get("is_saving"), original_is_saving, "Original is_saving unchanged")
	assert_eq(state.get("last_save_slot"), original_last_slot, "Original last_save_slot unchanged")


func test_unhandled_action_returns_same_state() -> void:
	var state := _make_state()
	var reduced := U_SaveReducer.reduce(state, {"type": StringName("noop")})

	assert_eq(reduced, state, "Reducer should return original state for unknown actions")


# ==============================================================================
# Helper Functions
# ==============================================================================

func _make_state() -> Dictionary:
	var initial: RS_SaveInitialState = RS_SaveInitialState.new()
	return initial.to_dictionary()
