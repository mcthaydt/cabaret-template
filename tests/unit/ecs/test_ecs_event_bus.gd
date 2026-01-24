extends BaseTest

const ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

const EVENT_NAME := StringName("test_event")
const OTHER_EVENT := StringName("other_event")

func before_each() -> void:
	ECS_EVENT_BUS.reset()

func test_publish_notifies_all_subscribers_in_subscription_order() -> void:
	var call_order: Array = []
	var payload: Dictionary = {"value": 1}
	var callback_a := func(event_data: Dictionary) -> void:
		call_order.append(StringName("A"))
		assert_eq(event_data.get("name"), EVENT_NAME)
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

func test_event_history_records_events() -> void:
	var payload_a: Dictionary = {"id": 1}
	var payload_b: Dictionary = {"id": 2}
	var payload_c: Dictionary = {"id": 3}

	ECS_EVENT_BUS.publish(EVENT_NAME, payload_a)
	ECS_EVENT_BUS.publish(OTHER_EVENT, payload_b)
	ECS_EVENT_BUS.publish(EVENT_NAME, payload_c)

	payload_a["id"] = 99
	payload_b["id"] = 100
	payload_c["id"] = 101

	var history: Array = ECS_EVENT_BUS.get_event_history()
	assert_eq(history.size(), 3)

	var first_event: Dictionary = history[0]
	assert_eq(first_event.get("name"), EVENT_NAME)
	assert_eq(first_event.get("payload"), {"id": 1})
	assert_true(first_event.has("timestamp"))
	assert_true(first_event["timestamp"] is float)

	var second_event: Dictionary = history[1]
	assert_eq(second_event.get("name"), OTHER_EVENT)
	assert_eq(second_event.get("payload"), {"id": 2})

	var third_event: Dictionary = history[2]
	assert_eq(third_event.get("name"), EVENT_NAME)
	assert_eq(third_event.get("payload"), {"id": 3})

func test_event_history_enforces_maximum_size() -> void:
	ECS_EVENT_BUS.set_history_limit(3)

	for i in range(5):
		var payload: Dictionary = {"index": i}
		ECS_EVENT_BUS.publish(EVENT_NAME, payload)

	var history: Array = ECS_EVENT_BUS.get_event_history()
	assert_eq(history.size(), 3)

	var recorded_indices: Array = []
	for event_data in history:
		var event_dict: Dictionary = event_data
		recorded_indices.append(event_dict.get("payload").get("index"))

	assert_eq(recorded_indices, [2, 3, 4])
