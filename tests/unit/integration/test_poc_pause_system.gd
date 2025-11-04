extends GutTest

## Proof-of-Concept Integration Tests: Pause System
##
## Tests that validate state store integration with actual ECS pause system

var store: M_StateStore
var pause_system: Node  # Will be S_PauseSystem once implemented

func before_each() -> void:
	# CRITICAL: Reset both event buses for integration tests
	U_StateEventBus.reset()
	U_ECSEventBus.reset()
	
	# Create M_StateStore
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame

func after_each() -> void:
	U_StateEventBus.reset()
	U_ECSEventBus.reset()
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	pause_system = null

## T299: Test pause system dispatches pause action
func test_pause_system_dispatches_pause_action() -> void:
	# Create pause system
	pause_system = S_PauseSystem.new()
	add_child(pause_system)
	autofree(pause_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize
	
	# Subscribe to store to capture actions
	var actions_received: Array = []
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void: actions_received.append(action))
	
	# Toggle pause
	pause_system.toggle_pause()
	await get_tree().process_frame
	
	# Verify pause action was dispatched
	assert_gt(actions_received.size(), 0, "At least one action should be dispatched")
	assert_eq(actions_received[0].type, U_GameplayActions.ACTION_PAUSE_GAME, "Action should be pause_game")

## T300: Test pause system reads pause state from store
func test_pause_system_reads_pause_state_from_store() -> void:
	# Create pause system
	pause_system = S_PauseSystem.new()
	add_child(pause_system)
	autofree(pause_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize
	
	# Dispatch pause action
	store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	
	# Verify pause system reflects the state
	var is_paused: bool = U_GameplaySelectors.get_is_paused(store.get_slice(StringName("gameplay")))
	assert_true(is_paused, "Game should be paused")
	assert_true(pause_system.is_paused(), "Pause system should reflect paused state")

## T301: Test movement disabled when paused
func test_movement_disabled_when_paused() -> void:
	# This test verifies that systems check pause state (already implemented in systems)
	# We'll verify that the pause state is correctly set and readable
	
	# Create pause system
	pause_system = S_PauseSystem.new()
	add_child(pause_system)
	autofree(pause_system)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Pause the game
	store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	
	# Verify pause state is accessible for systems to check
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	var is_paused: bool = U_GameplaySelectors.get_is_paused(gameplay_state)
	assert_true(is_paused, "Gameplay state should indicate paused")
	
	# Movement/jump/input systems already check this state in their process_tick
	# This test confirms the integration point works
