@icon("res://resources/editor_icons/system.svg")
extends BaseEventVFXSystem
class_name S_JumpSoundSystem

## Alias for EventVFXSystem.requests to maintain backward compatibility
var play_requests: Array:
	get:
		return requests

func get_event_name() -> StringName:
	return StringName("entity_jumped")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"entity": payload.get("entity"),
		"jump_time": payload.get("jump_time", payload.get("timestamp", 0.0)),
		"jump_force": payload.get("jump_force", 0.0),
		"supported": payload.get("supported", false),
	}

func process_tick(_delta: float) -> void:
	# Sound system implementation TBD
	# For now, just clear requests (behavior matches original)
	requests.clear()
