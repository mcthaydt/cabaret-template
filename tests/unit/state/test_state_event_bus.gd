extends GutTest

## Tests for StateStoreEventBus isolation and reset behavior

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")
const ECSEventBus := preload("res://scripts/ecs/ecs_event_bus.gd")

var callback_count: int = 0
var received_events: Array = []

func before_each() -> void:
	# CRITICAL: Reset both buses to prevent test pollution
	StateStoreEventBus.reset()
	ECSEventBus.reset()
	callback_count = 0
	received_events.clear()

func after_each() -> void:
	StateStoreEventBus.reset()
	ECSEventBus.reset()

## Test that StateStoreEventBus can subscribe and receive events
func test_state_bus_subscribe_and_publish() -> void:
	var event_name := StringName("state/test_event")
	var payload: Dictionary = {"data": "test"}
	
	var callback := func(event_data: Dictionary) -> void:
		received_events.append(event_data)
		callback_count += 1
	
	StateStoreEventBus.subscribe(event_name, callback)
	StateStoreEventBus.publish(event_name, payload)
	
	assert_eq(callback_count, 1, "Callback should be called once")
	assert_eq(received_events.size(), 1, "Should receive one event")
	if received_events.size() > 0:
		var event_data: Dictionary = received_events[0]
		var received_payload: Dictionary = event_data.get("payload", {})
		assert_eq(received_payload.get("data"), "test", "Payload should match")

## Test that StateStoreEventBus and ECSEventBus are isolated
func test_state_and_ecs_buses_are_isolated() -> void:
	var state_event_name := StringName("state/event")
	var ecs_event_name := StringName("ecs/event")
	
	var state_calls: Array = []
	var ecs_calls: Array = []
	
	var state_callback := func(_event: Dictionary) -> void:
		state_calls.append(1)
	
	var ecs_callback := func(_event: Dictionary) -> void:
		ecs_calls.append(1)
	
	# Subscribe to both buses
	StateStoreEventBus.subscribe(state_event_name, state_callback)
	ECSEventBus.subscribe(ecs_event_name, ecs_callback)
	
	# Publish to state bus
	StateStoreEventBus.publish(state_event_name, null)
	
	# Only state callback should fire
	assert_eq(state_calls.size(), 1, "State callback should fire")
	assert_eq(ecs_calls.size(), 0, "ECS callback should NOT fire from state event")
	
	# Publish to ECS bus
	ECSEventBus.publish(ecs_event_name, null)
	
	# Only ECS callback should fire
	assert_eq(state_calls.size(), 1, "State callback should still be 1")
	assert_eq(ecs_calls.size(), 1, "ECS callback should fire")

## Test that StateStoreEventBus.reset() clears subscribers without affecting ECSEventBus
func test_state_bus_reset_does_not_affect_ecs_bus() -> void:
	var state_event := StringName("state/test")
	var ecs_event := StringName("ecs/test")
	
	var state_calls: Array = []
	var ecs_calls: Array = []
	
	StateStoreEventBus.subscribe(state_event, func(_e: Dictionary) -> void:
		state_calls.append(1)
	)
	
	ECSEventBus.subscribe(ecs_event, func(_e: Dictionary) -> void:
		ecs_calls.append(1)
	)
	
	# Reset state bus only
	StateStoreEventBus.reset()
	
	# Publish to both
	StateStoreEventBus.publish(state_event, null)
	ECSEventBus.publish(ecs_event, null)
	
	# State subscriber should be gone, ECS subscriber should still work
	assert_eq(state_calls.size(), 0, "State subscriber should be cleared by reset")
	assert_eq(ecs_calls.size(), 1, "ECS subscriber should still work")

## Test that ECSEventBus.reset() clears subscribers without affecting StateStoreEventBus
func test_ecs_bus_reset_does_not_affect_state_bus() -> void:
	var state_event := StringName("state/test")
	var ecs_event := StringName("ecs/test")
	
	var state_calls: Array = []
	var ecs_calls: Array = []
	
	StateStoreEventBus.subscribe(state_event, func(_e: Dictionary) -> void:
		state_calls.append(1)
	)
	
	ECSEventBus.subscribe(ecs_event, func(_e: Dictionary) -> void:
		ecs_calls.append(1)
	)
	
	# Reset ECS bus only
	ECSEventBus.reset()
	
	# Publish to both
	StateStoreEventBus.publish(state_event, null)
	ECSEventBus.publish(ecs_event, null)
	
	# ECS subscriber should be gone, state subscriber should still work
	assert_eq(state_calls.size(), 1, "State subscriber should still work")
	assert_eq(ecs_calls.size(), 0, "ECS subscriber should be cleared by reset")

## Test that event history is isolated between buses
func test_event_history_is_isolated() -> void:
	var state_event := StringName("state/event")
	var ecs_event := StringName("ecs/event")
	
	# Publish to both buses
	StateStoreEventBus.publish(state_event, {"from": "state"})
	ECSEventBus.publish(ecs_event, {"from": "ecs"})
	
	var state_history: Array = StateStoreEventBus.get_event_history()
	var ecs_history: Array = ECSEventBus.get_event_history()
	
	# Each bus should have only its own event
	assert_eq(state_history.size(), 1, "State bus should have 1 event")
	assert_eq(ecs_history.size(), 1, "ECS bus should have 1 event")
	
	var state_event_data: Dictionary = state_history[0] as Dictionary
	var ecs_event_data: Dictionary = ecs_history[0] as Dictionary
	
	assert_eq(state_event_data.get("name"), state_event, "State history contains state event")
	assert_eq(ecs_event_data.get("name"), ecs_event, "ECS history contains ECS event")

## Test that unsubscribe works correctly
func test_unsubscribe_works() -> void:
	var event_name := StringName("state/test")
	var calls: Array = []
	
	var callback := func(_e: Dictionary) -> void:
		calls.append(1)
	
	var unsubscribe: Callable = StateStoreEventBus.subscribe(event_name, callback)
	
	# First publish
	StateStoreEventBus.publish(event_name, null)
	assert_eq(calls.size(), 1, "Callback should fire once")
	
	# Unsubscribe
	unsubscribe.call()
	
	# Second publish
	StateStoreEventBus.publish(event_name, null)
	assert_eq(calls.size(), 1, "Callback should not fire after unsubscribe")

## Test history limit works
func test_history_limit_works() -> void:
	StateStoreEventBus.set_history_limit(3)
	
	for i in 5:
		StateStoreEventBus.publish(StringName("event_%d" % i), {"index": i})
	
	var history: Array = StateStoreEventBus.get_event_history()
	
	assert_eq(history.size(), 3, "History should be limited to 3 entries")
	
	# Should have events 2, 3, 4 (oldest pruned)
	var last_event: Dictionary = history[2] as Dictionary
	var payload: Dictionary = last_event.get("payload", {})
	assert_eq(payload.get("index"), 4, "Last event should be index 4")
