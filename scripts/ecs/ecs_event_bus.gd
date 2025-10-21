extends RefCounted
class_name ECSEventBus

const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

static var _subscribers: Dictionary = {}

static func subscribe(event_name: StringName, callback: Callable) -> Callable:
	var normalized_event: StringName = event_name
	if normalized_event == StringName():
		push_error("ECSEventBus.subscribe called with empty event name.")
		return func() -> void:
			pass

	if not _subscribers.has(normalized_event):
		_subscribers[normalized_event] = []

	var subscriber_list: Array = _subscribers[normalized_event]
	if not subscriber_list.has(callback):
		subscriber_list.append(callback)

	return func() -> void:
		unsubscribe(normalized_event, callback)

static func unsubscribe(event_name: StringName, callback: Callable) -> void:
	var normalized_event: StringName = event_name
	if not _subscribers.has(normalized_event):
		return

	var subscriber_list: Array = _subscribers[normalized_event]
	subscriber_list.erase(callback)

	if subscriber_list.is_empty():
		_subscribers.erase(normalized_event)

static func publish(event_name: StringName, payload: Dictionary = {}) -> void:
	var normalized_event: StringName = event_name
	if not _subscribers.has(normalized_event):
		return

	var event_payload: Dictionary = {
		"event_name": normalized_event,
		"payload": payload.duplicate(true),
		"timestamp": U_ECS_UTILS.get_current_time(),
	}

	var subscribers: Array = _subscribers[normalized_event].duplicate()
	for subscriber in subscribers:
		var callback: Callable = subscriber
		if callback.is_valid():
			callback.call(event_payload)

static func clear(event_name: StringName = StringName()) -> void:
	if event_name == StringName():
		_subscribers.clear()
	else:
		_subscribers.erase(event_name)

static func reset() -> void:
	clear()
