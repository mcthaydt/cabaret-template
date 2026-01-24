@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name BaseEventSFXSystem

## Base class for SFX systems that respond to ECS events.
##
## Provides common patterns for event-driven SFX systems:
## - Event subscription/unsubscription lifecycle
## - Request queue management
## - Payload extraction
##
## Subclasses must implement:
## - get_event_name() -> StringName
## - create_request_from_payload(payload: Dictionary) -> Dictionary

const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

## Queue of SFX requests to be processed in process_tick().
var requests: Array = []

var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
	super._ready()
	_subscribe()

func _exit_tree() -> void:
	_unsubscribe()
	requests.clear()

## Override in subclass to return the event name to subscribe to.
func get_event_name() -> StringName:
	push_error("BaseEventSFXSystem: get_event_name() not implemented")
	return StringName()

## Override in subclass to create a request dictionary from event payload.
func create_request_from_payload(_payload: Dictionary) -> Dictionary:
	push_error("BaseEventSFXSystem: create_request_from_payload() not implemented")
	return {}

func _subscribe() -> void:
	_unsubscribe()
	requests.clear()

	var event_name := get_event_name()
	if event_name == StringName():
		push_warning("BaseEventSFXSystem: get_event_name() returned empty StringName")
		return

	_unsubscribe_callable = EVENT_BUS.subscribe(event_name, _on_event)

func _unsubscribe() -> void:
	if _unsubscribe_callable != Callable() and _unsubscribe_callable.is_valid():
		_unsubscribe_callable.call()
	_unsubscribe_callable = Callable()

func _on_event(event_data: Dictionary) -> void:
	var payload := _extract_payload(event_data)
	var request := create_request_from_payload(payload)
	if request.is_empty():
		return
	requests.append(request.duplicate(true))

func _extract_payload(event_data: Dictionary) -> Dictionary:
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		return event_data["payload"]
	return {}
