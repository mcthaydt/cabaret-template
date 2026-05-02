extends RefCounted
class_name BaseECSEvent

## Base class for all typed ECS events.
##
## Provides common timestamp tracking and payload serialization for event history.
## All concrete event classes should extend this and populate their _payload in _init().

var timestamp: float = 0.0
var _payload: Dictionary = {}

## Get a deep copy of the event payload for history/debugging.
func get_payload() -> Dictionary:
	return _payload.duplicate(true)
