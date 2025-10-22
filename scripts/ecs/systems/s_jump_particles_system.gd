@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_JumpParticlesSystem

const EVENT_NAME := StringName("entity_jumped")
const EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")

var spawn_requests: Array = []

var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
	super._ready()
	_subscribe()

func _exit_tree() -> void:
	_unsubscribe()
	spawn_requests.clear()

func process_tick(_delta: float) -> void:
	pass

func _subscribe() -> void:
	_unsubscribe()
	spawn_requests.clear()
	_unsubscribe_callable = EVENT_BUS.subscribe(EVENT_NAME, Callable(self, "_on_entity_jumped"))

func _unsubscribe() -> void:
	if _unsubscribe_callable != Callable():
		_unsubscribe_callable.call()
		_unsubscribe_callable = Callable()

func _on_entity_jumped(event_data: Dictionary) -> void:
	var payload := _extract_payload(event_data)
	var request := {
		"position": payload.get("position", Vector3.ZERO),
		"velocity": payload.get("velocity", Vector3.ZERO),
		"timestamp": event_data.get("timestamp", 0.0),
		"jump_force": payload.get("jump_force", 0.0),
	}
	spawn_requests.append(request.duplicate(true))

func _extract_payload(event_data: Dictionary) -> Dictionary:
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		return event_data["payload"]
	return {}
