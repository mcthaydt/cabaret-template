extends RefCounted
class_name EventBusBase

## Abstract base class for event buses providing shared subscription and history logic.
##
## Concrete subclasses (U_ECSEventBus, U_StateEventBus) extend this and expose
## static APIs that delegate to private instances, maintaining domain isolation.

const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const DEFAULT_MAX_HISTORY_SIZE := 1000

var _subscribers: Dictionary = {}
var _event_history: Array = []
var _max_history_size: int = DEFAULT_MAX_HISTORY_SIZE

## Subscribe to an event. Returns unsubscribe callable.
func subscribe(event_name: StringName, callback: Callable) -> Callable:
	var normalized_event: StringName = event_name
	if normalized_event == StringName():
		push_error("EventBusBase.subscribe called with empty event name.")
		return func() -> void:
			pass

	if callback == Callable():
		push_error("EventBusBase.subscribe called with invalid callback.")
		return func() -> void:
			pass

	if not _subscribers.has(normalized_event):
		_subscribers[normalized_event] = []

	var subscriber_list: Array = _subscribers[normalized_event]
	if not subscriber_list.has(callback):
		subscriber_list.append(callback)

	return func() -> void:
		unsubscribe(normalized_event, callback)

## Unsubscribe from an event.
func unsubscribe(event_name: StringName, callback: Callable) -> void:
	var normalized_event: StringName = event_name
	if not _subscribers.has(normalized_event):
		return

	var subscriber_list: Array = _subscribers[normalized_event]
	subscriber_list.erase(callback)

	if subscriber_list.is_empty():
		_subscribers.erase(normalized_event)

## Publish an event to all subscribers.
func publish(event_name: StringName, payload: Variant = null) -> void:
	var normalized_event: StringName = event_name
	if normalized_event == StringName():
		push_error("EventBusBase.publish called with empty event name.")
		return

	var event_payload: Dictionary = {
		"name": normalized_event,
		"payload": _duplicate_payload(payload),
		"timestamp": U_ECS_UTILS.get_current_time(),
	}

	_append_to_history(event_payload)

	if not _subscribers.has(normalized_event):
		return

	var subscribers: Array = _subscribers[normalized_event].duplicate()
	for subscriber in subscribers:
		var callback: Callable = subscriber
		if callback.is_valid():
			callback.call(event_payload)

## Clear subscribers for a specific event, or all if event_name is empty.
func clear(event_name: StringName = StringName()) -> void:
	if event_name == StringName():
		_subscribers.clear()
	else:
		_subscribers.erase(event_name)

## Clear event history.
func clear_history() -> void:
	_event_history.clear()

## Reset bus to initial state (clear subscribers and history).
func reset() -> void:
	clear()
	clear_history()
	_max_history_size = DEFAULT_MAX_HISTORY_SIZE

## Get copy of event history.
func get_event_history() -> Array:
	return _event_history.duplicate(true)

## Set maximum history size (circular buffer).
func set_history_limit(limit: int) -> void:
	var normalized_limit: int = max(limit, 1)
	_max_history_size = normalized_limit
	_trim_history()

func _append_to_history(event_payload: Dictionary) -> void:
	_event_history.append(event_payload.duplicate(true))
	_trim_history()

func _trim_history() -> void:
	while _event_history.size() > _max_history_size:
		_event_history.pop_front()

func _duplicate_payload(payload: Variant) -> Variant:
	if payload is Dictionary:
		return (payload as Dictionary).duplicate(true)
	if payload is Array:
		return (payload as Array).duplicate(true)
	return payload
