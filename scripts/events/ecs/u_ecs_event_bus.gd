extends RefCounted
class_name U_ECSEventBus

## Event bus for ECS domain.
##
## Provides isolated event infrastructure for ECS systems and components,
## separate from state store event domain. Delegates to EventBusBase instance.

const EVENT_BUS_BASE := preload("res://scripts/events/base_event_bus.gd")
const BASE_ECS_EVENT := preload("res://scripts/events/ecs/base_ecs_event.gd")

static var _instance: BaseEventBus = null

static func _get_instance() -> BaseEventBus:
	if _instance == null:
		_instance = EVENT_BUS_BASE.new()
	return _instance

## Subscribe to an ECS event with optional priority. Returns unsubscribe callable.
## Higher priority subscribers are called first (10 > 5 > 0).
static func subscribe(event_name: StringName, callback: Callable, priority: int = 0) -> Callable:
	return _get_instance().subscribe(event_name, callback, priority)

## Unsubscribe from an ECS event.
static func unsubscribe(event_name: StringName, callback: Callable) -> void:
	_get_instance().unsubscribe(event_name, callback)

## Publish an ECS event to all subscribers.
static func publish(event_name: StringName, payload: Variant = null) -> void:
	_get_instance().publish(event_name, payload)

## Publish a typed ECS event to all subscribers.
## Extracts event name from class (e.g., Evn_HealthChanged -> health_changed).
static func publish_typed(event: BaseECSEvent) -> void:
	var event_name := _event_class_to_name(event)
	_get_instance().publish(event_name, event.get_payload())

## Clear subscribers for a specific event, or all if event_name is empty.
static func clear(event_name: StringName = StringName()) -> void:
	_get_instance().clear(event_name)

## Clear event history.
static func clear_history() -> void:
	_get_instance().clear_history()

## Reset bus to initial state (clear subscribers and history).
## CRITICAL: Call this in before_each() for ECS tests to prevent subscription leaks.
static func reset() -> void:
	if _instance != null:
		_instance.reset()
	_instance = null

## Get copy of event history.
static func get_event_history() -> Array:
	return _get_instance().get_event_history()

## Set maximum history size (circular buffer).
static func set_history_limit(limit: int) -> void:
	_get_instance().set_history_limit(limit)

## Convert typed event class to event name.
## Example: Evn_HealthChanged -> "health_changed"
static func _event_class_to_name(event: BaseECSEvent) -> StringName:
	# Get the script's class_name, not the base class
	var script: Script = event.get_script()
	if script == null:
		push_error("Event has no script attached")
		return StringName("")

	var event_class: String = script.get_global_name()
	if event_class.is_empty():
		push_error("Event script has no class_name defined")
		return StringName("")

	# Remove "Evn_" prefix and convert to snake_case
	var name_without_prefix: String = event_class.replace("Evn_", "")
	var snake: String = name_without_prefix.to_snake_case()
	return StringName(snake)
