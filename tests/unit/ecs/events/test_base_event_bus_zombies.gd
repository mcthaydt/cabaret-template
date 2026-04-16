extends GutTest

const BASE_EVENT_BUS := preload("res://scripts/events/base_event_bus.gd")

const EVENT_NAME := StringName("test_event")
const OTHER_EVENT := StringName("other_event")

var _bus: BaseEventBus

func before_each() -> void:
	_bus = BASE_EVENT_BUS.new()

func after_each() -> void:
	_bus = null

class ZombieHelper extends Node:
	func on_event(_event_data: Dictionary) -> void:
		pass

## Subscribe with a valid callable, then free the object to create a zombie.
func _subscribe_zombie(event_name: StringName) -> void:
	var node := ZombieHelper.new()
	_bus.subscribe(event_name, node.on_event)
	node.free()

func _count_valid_subscribers(event_name: StringName) -> int:
	if not _bus._subscribers.has(event_name):
		return 0
	var count: int = 0
	for sub_meta in _bus._subscribers[event_name]:
		if sub_meta.callback.is_valid():
			count += 1
	return count

func _has_any_zombie(event_name: StringName) -> bool:
	if not _bus._subscribers.has(event_name):
		return false
	for sub_meta in _bus._subscribers[event_name]:
		if not sub_meta.callback.is_valid():
			return true
	return false

func test_zombie_removed_from_subscriber_list_after_publish() -> void:
	_subscribe_zombie(EVENT_NAME)
	_bus.publish(EVENT_NAME)

	assert_false(_has_any_zombie(EVENT_NAME),
		"No zombie subscribers should remain in list after publish")

func test_zombie_only_event_pruned_from_dict() -> void:
	_subscribe_zombie(EVENT_NAME)
	_bus.publish(EVENT_NAME)

	assert_false(_bus._subscribers.has(EVENT_NAME),
		"Event with only zombies should be removed from subscribers dict")

func test_mixed_zombie_and_live_subscribers_after_publish() -> void:
	_subscribe_zombie(EVENT_NAME)
	var call_log: Array = []
	var live_cb := func(_event_data: Dictionary) -> void:
		call_log.append("called")
	_bus.subscribe(EVENT_NAME, live_cb)
	_bus.publish(EVENT_NAME)

	assert_eq(call_log.size(), 1, "Live subscriber should still receive events")
	assert_eq(_count_valid_subscribers(EVENT_NAME), 1,
		"Exactly one valid subscriber should remain (the live one)")
	assert_false(_has_any_zombie(EVENT_NAME),
		"No zombie subscribers should remain after publish")

func test_multiple_zombies_pruned_in_single_publish() -> void:
	_subscribe_zombie(EVENT_NAME)
	_subscribe_zombie(EVENT_NAME)
	var call_log: Array = []
	var live_cb := func(_event_data: Dictionary) -> void:
		call_log.append("called")
	_bus.subscribe(EVENT_NAME, live_cb)
	_bus.publish(EVENT_NAME)

	assert_eq(call_log.size(), 1, "Live subscriber should receive events")
	assert_eq(_count_valid_subscribers(EVENT_NAME), 1,
		"Only live subscriber should remain after pruning two zombies")

func test_zombie_pruning_does_not_affect_other_events() -> void:
	_subscribe_zombie(EVENT_NAME)
	var call_log: Array = []
	var live_cb := func(_event_data: Dictionary) -> void:
		call_log.append("called")
	_bus.subscribe(OTHER_EVENT, live_cb)
	_bus.publish(EVENT_NAME)
	_bus.publish(OTHER_EVENT)

	assert_eq(call_log.size(), 1, "Subscriber on different event should be unaffected")
	assert_eq(_count_valid_subscribers(OTHER_EVENT), 1,
		"Other event's subscriber list should be intact")

func test_reentrant_subscribe_during_publish_does_not_skip_subscribers() -> void:
	var call_order: Array = []
	var callback_b := func(_event_data: Dictionary) -> void:
		call_order.append("B")
	var callback_a := func(_event_data: Dictionary) -> void:
		call_order.append("A")
		_bus.subscribe(EVENT_NAME, func(_ed: Dictionary) -> void:
			call_order.append("C"))
	_bus.subscribe(EVENT_NAME, callback_a)
	_bus.subscribe(EVENT_NAME, callback_b)
	_bus.publish(EVENT_NAME)

	assert_has(call_order, "A", "Callback A should be called")
	assert_has(call_order, "B", "Callback B should be called")

func test_reentrant_unsubscribe_during_publish_does_not_skip_subscribers() -> void:
	var call_order: Array = []
	var callback_b: Callable
	var callback_a := func(_event_data: Dictionary) -> void:
		call_order.append("A")
		_bus.unsubscribe(EVENT_NAME, callback_b)
	callback_b = func(_event_data: Dictionary) -> void:
		call_order.append("B")
	_bus.subscribe(EVENT_NAME, callback_a)
	_bus.subscribe(EVENT_NAME, callback_b)
	_bus.publish(EVENT_NAME)

	assert_has(call_order, "A", "Callback A should be called")
	assert_has(call_order, "B", "Callback B should be called despite mid-iterate unsubscribe")

func test_reentrant_clear_during_publish_does_not_crash() -> void:
	var call_log: Array = []
	var callback_a := func(_event_data: Dictionary) -> void:
		call_log.append("A")
		_bus.clear()
	var callback_b := func(_event_data: Dictionary) -> void:
		call_log.append("B")
	_bus.subscribe(EVENT_NAME, callback_a)
	_bus.subscribe(EVENT_NAME, callback_b)
	_bus.publish(EVENT_NAME)

	assert_has(call_log, "A", "Callback A should be called")
	# Callback B may or may not be called after clear — the contract is "no crash"