extends GutTest

## Tests for GameplayReducer pure functions

const U_StateEventBus := preload("res://scripts/state/u_state_event_bus.gd")
const StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

func before_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()  # Clear any state from previous tests

func after_each() -> void:
	U_StateEventBus.reset()
	StateHandoff.clear_all()

## Test that reducer is a pure function (same inputs = same outputs)
func test_reducer_is_pure_function() -> void:
	var state: Dictionary = {"paused": false, "entities": {}}
	var action: Dictionary = U_GameplayActions.pause_game()
	
	var result1: Dictionary = U_GameplayReducer.reduce(state, action)
	var result2: Dictionary = U_GameplayReducer.reduce(state, action)
	
	assert_eq(result1, result2, "Same inputs should produce same outputs (pure function)")

## Test that reducer does not mutate original state (immutability)
func test_reducer_does_not_mutate_original_state() -> void:
	var original_state: Dictionary = {"paused": false, "entities": {}}
	var action: Dictionary = U_GameplayActions.pause_game()
	
	var _new_state: Dictionary = U_GameplayReducer.reduce(original_state, action)
	
	assert_eq(original_state["paused"], false, "Original state should remain unchanged")
	assert_eq(original_state.has("entities"), true, "Original state fields should remain unchanged")

## Test pause action sets paused to true
func test_pause_action_sets_paused_to_true() -> void:
	var state: Dictionary = {"paused": false}
	var action: Dictionary = U_GameplayActions.pause_game()
	
	var result: Dictionary = U_GameplayReducer.reduce(state, action)
	
	assert_eq(result["paused"], true, "Pause action should set paused to true")

## Test unpause action sets paused to false
func test_unpause_action_sets_paused_to_false() -> void:
	var state: Dictionary = {"paused": true}
	var action: Dictionary = U_GameplayActions.unpause_game()
	
	var result: Dictionary = U_GameplayReducer.reduce(state, action)
	
	assert_eq(result["paused"], false, "Unpause action should set paused to false")

## Test unknown action returns state unchanged
func test_unknown_action_returns_state_unchanged() -> void:
	var state: Dictionary = {"paused": false, "entities": {}}
	var unknown_action: Dictionary = {"type": StringName("unknown/action"), "payload": null}
	
	var result: Dictionary = U_GameplayReducer.reduce(state, unknown_action)
	
	assert_eq(result, state, "Unknown action should return state unchanged")

## Test pause/unpause toggle sequence maintains immutability
func test_pause_unpause_toggle_sequence() -> void:
	var state: Dictionary = {"paused": false}
	
	# Pause
	var paused_state: Dictionary = U_GameplayReducer.reduce(state, U_GameplayActions.pause_game())
	assert_eq(paused_state["paused"], true, "Should be paused")
	
	# Unpause
	var unpaused_state: Dictionary = U_GameplayReducer.reduce(paused_state, U_GameplayActions.unpause_game())
	assert_eq(unpaused_state["paused"], false, "Should be unpaused")
	
	# Original unchanged
	assert_eq(state["paused"], false, "Original state should never mutate")

## Test initial state loads from resource
func test_initial_state_loads_from_resource() -> void:
	var store := M_StateStore.new()
	
	# Create and assign initial state
	var initial_state := RS_GameplayInitialState.new()
	initial_state.paused = true
	initial_state.gravity_scale = 1.5
	store.gameplay_initial_state = initial_state
	
	# Explicitly assign settings to prevent warning
	store.settings = RS_StateStoreSettings.new()
	
	add_child(store)
	autofree(store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# Check that gameplay slice initialized with resource values
	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_slice.get("paused"), true, "Paused should match resource")
	assert_eq(gameplay_slice.get("gravity_scale"), 1.5, "Gravity scale should match resource")

## Phase 16.5: Mock data tests removed - using entity coordination pattern instead
## Tests for entity snapshots are in test_entity_coordination.gd
