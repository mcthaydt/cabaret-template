@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_JumpSoundSystem

const EVENT_NAME := StringName("entity_jumped")
const EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")

var play_requests: Array = []

var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
	super._ready()
	_subscribe()

func _exit_tree() -> void:
	_unsubscribe()
	play_requests.clear()

func process_tick(_delta: float) -> void:
	pass

func _subscribe() -> void:
	_unsubscribe()
	play_requests.clear()
	_unsubscribe_callable = EVENT_BUS.subscribe(EVENT_NAME, Callable(self, "_on_entity_jumped"))

func _unsubscribe() -> void:
	if _unsubscribe_callable != Callable():
		_unsubscribe_callable.call()
		_unsubscribe_callable = Callable()

func _on_entity_jumped(event_data: Dictionary) -> void:
	var payload := _extract_payload(event_data)
	var request := {
		"entity": payload.get("entity"),
		"jump_time": payload.get("jump_time", event_data.get("timestamp", 0.0)),
		"jump_force": payload.get("jump_force", 0.0),
		"supported": payload.get("supported", false),
	}
	play_requests.append(request.duplicate(true))

func _extract_payload(event_data: Dictionary) -> Dictionary:
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		return event_data["payload"]
	return {}
