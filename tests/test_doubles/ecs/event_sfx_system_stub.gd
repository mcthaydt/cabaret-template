extends "res://scripts/ecs/base_event_sfx_system.gd"

var event_name: StringName = StringName()
var request_builder: Callable = Callable()
var mock_audio_stream: AudioStream = null
var _last_play_time: float = -INF

func get_event_name() -> StringName:
	return event_name

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	if request_builder != Callable() and request_builder.is_valid():
		return request_builder.call(payload)
	return {"data": payload.get("value", "")}

func _get_audio_stream() -> AudioStream:
	return mock_audio_stream
