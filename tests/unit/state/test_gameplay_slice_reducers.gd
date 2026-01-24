extends GutTest

## Tests for GameplayReducer pure functions

const U_StateEventBus := preload("res://scripts/events/state/u_state_event_bus.gd")
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

	# Disable persistence to prevent loading from save file
	var settings := RS_StateStoreSettings.new()
	settings.enable_persistence = false
	store.settings = settings
	
	add_child(store)
	autofree(store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# Check that gameplay slice initialized with resource values
	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_slice.get("paused"), true, "Paused should match resource")
	assert_eq(gameplay_slice.get("gravity_scale"), 1.5, "Gravity scale should match resource")

func test_reset_progress_restores_initial_fields() -> void:
	var state: Dictionary = {
		"paused": true,
		"move_input": Vector2.ONE,
		"look_input": Vector2(3.0, -2.0),
		"jump_pressed": true,
		"jump_just_pressed": true,
		"player_health": 12.0,
		"player_max_health": 100.0,
		"death_count": 5,
		"completed_areas": ["exterior", "interior_house"],
		"last_victory_objective": StringName("final_goal"),
		"game_completed": true,
		"target_spawn_point": StringName("spawn_exit"),
		"entities": {"E_Player": {"health": 12.0, "is_dead": true}}
	}

	var result: Dictionary = U_GameplayReducer.reduce(state, U_GameplayActions.reset_progress())

	assert_false(result.get("paused", true), "Reset should unpause gameplay")
	assert_eq(result.get("move_input", Vector2.ONE), Vector2.ZERO, "Reset should clear move input")
	assert_eq(result.get("look_input", Vector2.ONE), Vector2.ZERO, "Reset should clear look input")
	assert_false(result.get("jump_pressed", true), "Reset should clear jump_pressed")
	assert_false(result.get("jump_just_pressed", true), "Reset should clear jump_just_pressed")

	assert_eq(float(result.get("player_health", -1.0)), float(result.get("player_max_health", -1.0)),
		"Reset should restore player health to max")
	assert_eq(int(result.get("death_count", -1)), 0, "Reset should clear death count")
	assert_true(result.get("completed_areas", []).is_empty(), "Reset should clear completed areas")
	assert_eq(result.get("last_victory_objective", StringName("sentinel")), StringName(""),
		"Reset should clear last victory objective")
	assert_false(result.get("game_completed", true), "Reset should clear game_completed")
	assert_eq(result.get("target_spawn_point", StringName("sentinel")), StringName(""),
		"Reset should clear target spawn point")
	var entities_result: Variant = result.get("entities", {})
	assert_true(entities_result is Dictionary, "Entities should remain a dictionary")
	if (entities_result as Dictionary).has("E_Player"):
		var player_snapshot: Dictionary = (entities_result as Dictionary)["E_Player"]
		assert_eq(float(player_snapshot.get("health", -1.0)), float(result.get("player_max_health", -1.0)),
			"Player snapshot health should reset to max")
		assert_false(player_snapshot.get("is_dead", true), "Player snapshot should clear is_dead flag")
		assert_eq((entities_result as Dictionary).size(), 1,
			"Only player snapshot should remain after reset")
	else:
		assert_true((entities_result as Dictionary).is_empty(), "No entity snapshots should remain after reset")

	# Ensure original state untouched
	assert_eq(state.get("completed_areas", []).size(), 2, "Original completed areas should remain unchanged")
	assert_true(state.get("entities", {}).has("E_Player"), "Original entities dictionary should remain intact")

func test_apply_input_action_handles_null_state() -> void:
	var action := U_InputActions.update_move_input(Vector2(0.25, -0.75))
	var callable := Callable(U_GameplayReducer, "_apply_input_action")
	var result: Variant = callable.callv([null, action])
	assert_not_null(result)
	var input_state: Dictionary = result.get("input", {})
	assert_almost_eq((input_state.get("move_input", Vector2.ZERO) as Vector2).x, 0.25, 0.0001)
	assert_almost_eq((input_state.get("move_input", Vector2.ZERO) as Vector2).y, -0.75, 0.0001)

## Phase 16.5: Mock data tests removed - using entity coordination pattern instead
## Tests for entity snapshots are in test_entity_coordination.gd
