extends RefCounted
class_name BaseEventBus

## Abstract base class for event buses providing shared subscription and history logic.
##
## Concrete subclasses (U_ECSEventBus, U_StateEventBus) extend this and expose
## static APIs that delegate to private instances, maintaining domain isolation.

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const DEFAULT_MAX_HISTORY_SIZE := 1000

var _subscribers: Dictionary = {}
var _event_history: Array = []
var _max_history_size: int = DEFAULT_MAX_HISTORY_SIZE

## Subscribe to an event with optional priority. Returns unsubscribe callable.
## Higher priority subscribers are called first (10 > 5 > 0).
func subscribe(event_name: StringName, callback: Callable, priority: int = 0) -> Callable:
	var normalized_event: StringName = event_name
	if normalized_event == StringName():
		push_error("BaseEventBus.subscribe called with empty event name.")
		return func() -> void:
			pass

	if callback == Callable():
		push_error("BaseEventBus.subscribe called with invalid callback.")
		return func() -> void:
			pass

	if not _subscribers.has(normalized_event):
		_subscribers[normalized_event] = []

	var subscriber_list: Array = _subscribers[normalized_event]

	# Get callback source for logging
	var source := _get_callback_source(callback)

	# Check for duplicate subscriptions
	for sub_meta in subscriber_list:
		if sub_meta.callback == callback:
			push_warning("BaseEventBus: Duplicate subscription to '%s' from %s" % [event_name, source])
			return func() -> void:
				pass

	# Add subscriber with metadata
	subscriber_list.append({
		"callback": callback,
		"priority": priority,
		"source": source
	})

	# Sort by priority (higher first)
	subscriber_list.sort_custom(func(a, b): return a.priority > b.priority)

	return func() -> void:
		unsubscribe(normalized_event, callback)

## Unsubscribe from an event.
func unsubscribe(event_name: StringName, callback: Callable) -> void:
	var normalized_event: StringName = event_name
	if not _subscribers.has(normalized_event):
		return

	var subscriber_list: Array = _subscribers[normalized_event]

	# Find and remove subscriber by callback
	for i in range(subscriber_list.size() - 1, -1, -1):
		if subscriber_list[i].callback == callback:
			subscriber_list.remove_at(i)
			break

	if subscriber_list.is_empty():
		_subscribers.erase(normalized_event)

## Publish an event to all subscribers.
func publish(event_name: StringName, payload: Variant = null) -> void:
	var normalized_event: StringName = event_name
	if normalized_event == StringName():
		push_error("BaseEventBus.publish called with empty event name.")
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
	for sub_meta in subscribers:
		var callback: Callable = sub_meta.callback
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

## Get readable source info from callback for debugging.
func _get_callback_source(callback: Callable) -> String:
	var obj := callback.get_object()
	if obj == null:
		return "unknown"

	var script: Script = obj.get_script()
	if script != null:
		var path: String = script.resource_path
		# Extract just the filename
		var filename := path.get_file()
		return filename

	# Fallback to class name
	var obj_class: String = obj.get_class()
	return obj_class if obj_class else "unknown"
