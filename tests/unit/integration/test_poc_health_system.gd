extends GutTest

## Proof-of-Concept Integration Tests: Health System
##
## Tests that validate state store integration with health system

var store: M_StateStore
var health_system: Node  # Will be S_HealthSystem once implemented

func before_each() -> void:
	# CRITICAL: Reset both event buses and state handoff for integration tests
	StateStoreEventBus.reset()
	ECSEventBus.reset()
	StateHandoff.clear_all()
	
	# Create M_StateStore
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.gameplay_initial_state.health = 100
	autofree(store)
	add_child(store)
	await get_tree().process_frame

func after_each() -> void:
	StateStoreEventBus.reset()
	ECSEventBus.reset()
	StateHandoff.clear_all()
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	health_system = null

## T303: Test health system dispatches damage action
func test_health_system_dispatches_damage_action() -> void:
	# Create health system
	health_system = S_HealthSystem.new()
	add_child(health_system)
	autofree(health_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize
	
	# Subscribe to store to capture actions
	var actions_received: Array = []
	var unsubscribe := store.subscribe(func(action: Dictionary, _state: Dictionary) -> void: actions_received.append(action))
	
	# Find the damage timer (it's a Timer child node created by the system)
	var timer: Timer = null
	for child in health_system.get_children():
		if child is Timer:
			timer = child as Timer
			break
	assert_not_null(timer, "Health system should have a Timer child")
	
	# Force a timeout to trigger damage
	timer.timeout.emit()
	await get_tree().process_frame
	
	# Verify damage action was dispatched
	assert_gt(actions_received.size(), 0, "At least one action should be dispatched")
	assert_eq(actions_received[0].type, U_GameplayActions.ACTION_TAKE_DAMAGE, "Action should be take_damage")
	assert_eq(actions_received[0].payload.amount, 10, "Damage amount should be 10")

## T304: Test health decreases over time
func test_health_decreases_over_time() -> void:
	# Check initial health before creating system (to avoid timer firing)
	var initial_health: int = GameplaySelectors.get_current_health(store.get_slice(StringName("gameplay")))
	assert_eq(initial_health, 100, "Initial health should be 100")
	
	# Create health system
	health_system = S_HealthSystem.new()
	add_child(health_system)
	autofree(health_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize
	
	# Find the damage timer
	var timer: Timer = null
	for child in health_system.get_children():
		if child is Timer:
			timer = child as Timer
			break
	assert_not_null(timer, "Health system should have a Timer child")
	
	# Trigger damage by emitting timer timeout
	timer.timeout.emit()
	await get_tree().process_frame
	
	# Check health decreased
	var new_health: int = GameplaySelectors.get_current_health(store.get_slice(StringName("gameplay")))
	assert_eq(new_health, 90, "Health should decrease to 90 after one damage tick")

## T305: Test death at zero health
func test_death_at_zero_health() -> void:
	# Create health system
	health_system = S_HealthSystem.new()
	add_child(health_system)
	autofree(health_system)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for system to initialize
	
	# Track death signal
	var death_signal_received := [false]  # Array to capture in lambda
	health_system.player_died.connect(func() -> void: death_signal_received[0] = true)
	
	# Set health to 0
	store.dispatch(U_GameplayActions.update_health(0))
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for slice_updated signal to propagate
	
	# Verify player is dead
	var is_alive: bool = GameplaySelectors.get_is_player_alive(store.get_slice(StringName("gameplay")))
	assert_false(is_alive, "Player should not be alive with 0 health")
	assert_true(death_signal_received[0], "player_died signal should be emitted")
