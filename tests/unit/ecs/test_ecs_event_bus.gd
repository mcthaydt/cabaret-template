extends BaseTest

const ECS_EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")

const EVENT_NAME := StringName("test_event")
const OTHER_EVENT := StringName("other_event")

func before_each() -> void:
	ECS_EVENT_BUS.reset()

func test_publish_notifies_all_subscribers_in_subscription_order() -> void:
	var call_order: Array = []
	var payload: Dictionary = {"value": 1}
	var callback_a := func(event_data: Dictionary) -> void:
		call_order.append(StringName("A"))
		assert_eq(event_data.get("event_name"), EVENT_NAME)
		assert_true(event_data.has("timestamp"))
		assert_true(event_data["timestamp"] is float)
		assert_eq(event_data.get("payload"), payload)
	var callback_b := func(_event_data: Dictionary) -> void:
		call_order.append(StringName("B"))

	var unsubscribe_a: Callable = ECS_EVENT_BUS.subscribe(EVENT_NAME, callback_a)
	ECS_EVENT_BUS.subscribe(EVENT_NAME, callback_b)

	ECS_EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(call_order, [StringName("A"), StringName("B")])
	unsubscribe_a.call()

func test_unsubscribe_callable_removes_subscriber() -> void:
	var received: bool = false
	var callback := func(_event_data: Dictionary) -> void:
		received = true

	var unsubscribe: Callable = ECS_EVENT_BUS.subscribe(EVENT_NAME, callback)
	unsubscribe.call()

	var payload: Dictionary = {}
	ECS_EVENT_BUS.publish(EVENT_NAME, payload)

	assert_false(received)

func test_subscribers_are_isolated_by_event_name() -> void:
	var received: bool = false
	var other_callback := func(_event_data: Dictionary) -> void:
		received = true

	ECS_EVENT_BUS.subscribe(OTHER_EVENT, other_callback)
	var payload: Dictionary = {}
	ECS_EVENT_BUS.publish(EVENT_NAME, payload)

	assert_false(received)

func test_clear_removes_all_subscribers() -> void:
	var received: bool = false
	var callback := func(_event_data: Dictionary) -> void:
		received = true

	ECS_EVENT_BUS.subscribe(EVENT_NAME, callback)
	ECS_EVENT_BUS.clear()
	var payload: Dictionary = {}
	ECS_EVENT_BUS.publish(EVENT_NAME, payload)

	assert_false(received)
