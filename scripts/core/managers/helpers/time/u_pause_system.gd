extends RefCounted
class_name U_PauseSystem

const CHANNEL_UI := &"ui"
const CHANNEL_CUTSCENE := &"cutscene"
const CHANNEL_DEBUG := &"debug"
const CHANNEL_SYSTEM := &"system"

var _channels: Dictionary = {}

func request_pause(channel: StringName) -> void:
	if channel == CHANNEL_UI:
		return
	var count: int = int(_channels.get(channel, 0))
	_channels[channel] = count + 1

func release_pause(channel: StringName) -> void:
	if channel == CHANNEL_UI:
		return
	var count: int = int(_channels.get(channel, 0))
	var next_count: int = maxi(count - 1, 0)
	if next_count > 0:
		_channels[channel] = next_count
	else:
		_channels.erase(channel)

func is_channel_paused(channel: StringName) -> bool:
	return int(_channels.get(channel, 0)) > 0

func compute_is_paused() -> bool:
	for count_variant: Variant in _channels.values():
		var count: int = int(count_variant)
		if count > 0:
			return true
	return false

func get_active_channels() -> Array[StringName]:
	var active: Array[StringName] = []
	for key_variant: Variant in _channels.keys():
		var channel: StringName = key_variant
		if int(_channels.get(channel, 0)) > 0:
			active.append(channel)
	return active

func derive_pause_from_overlay_state(overlay_count: int) -> void:
	if overlay_count > 0:
		_channels[CHANNEL_UI] = 1
	else:
		_channels.erase(CHANNEL_UI)
