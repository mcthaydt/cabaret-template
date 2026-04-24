extends Node
class_name I_TimeManager

## Minimal interface for M_TimeManager.
## Enables dependency injection and mock testing.

func is_paused() -> bool:
	push_error("I_TimeManager.is_paused not implemented")
	return false

func request_pause(_channel: StringName) -> void:
	push_error("I_TimeManager.request_pause not implemented")

func release_pause(_channel: StringName) -> void:
	push_error("I_TimeManager.release_pause not implemented")

func is_channel_paused(_channel: StringName) -> bool:
	push_error("I_TimeManager.is_channel_paused not implemented")
	return false

func get_active_pause_channels() -> Array[StringName]:
	push_error("I_TimeManager.get_active_pause_channels not implemented")
	return []

func set_timescale(_scale: float) -> void:
	push_error("I_TimeManager.set_timescale not implemented")

func get_timescale() -> float:
	push_error("I_TimeManager.get_timescale not implemented")
	return 1.0

func get_scaled_delta(_raw_delta: float) -> float:
	push_error("I_TimeManager.get_scaled_delta not implemented")
	return _raw_delta

func get_world_time() -> Dictionary:
	push_error("I_TimeManager.get_world_time not implemented")
	return {}

func set_world_time(_hour: int, _minute: int) -> void:
	push_error("I_TimeManager.set_world_time not implemented")

func set_world_time_speed(_minutes_per_real_second: float) -> void:
	push_error("I_TimeManager.set_world_time_speed not implemented")

func is_daytime() -> bool:
	push_error("I_TimeManager.is_daytime not implemented")
	return true
