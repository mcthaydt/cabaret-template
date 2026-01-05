extends RefCounted
class_name U_AudioSelectors

## Audio Selectors (Audio Manager Phase 0 - Task 0.6)
##
## Pure selector functions for reading Audio slice state. Provides safe defaults
## when audio slice or fields are missing.

static func get_master_volume(state: Dictionary) -> float:
	var audio := _get_audio_slice(state)
	return float(audio.get("master_volume", 1.0))

static func get_music_volume(state: Dictionary) -> float:
	var audio := _get_audio_slice(state)
	return float(audio.get("music_volume", 1.0))

static func get_sfx_volume(state: Dictionary) -> float:
	var audio := _get_audio_slice(state)
	return float(audio.get("sfx_volume", 1.0))

static func get_ambient_volume(state: Dictionary) -> float:
	var audio := _get_audio_slice(state)
	return float(audio.get("ambient_volume", 1.0))

static func is_master_muted(state: Dictionary) -> bool:
	var audio := _get_audio_slice(state)
	return bool(audio.get("master_muted", false))

static func is_music_muted(state: Dictionary) -> bool:
	var audio := _get_audio_slice(state)
	return bool(audio.get("music_muted", false))

static func is_sfx_muted(state: Dictionary) -> bool:
	var audio := _get_audio_slice(state)
	return bool(audio.get("sfx_muted", false))

static func is_ambient_muted(state: Dictionary) -> bool:
	var audio := _get_audio_slice(state)
	return bool(audio.get("ambient_muted", false))

static func is_spatial_audio_enabled(state: Dictionary) -> bool:
	var audio := _get_audio_slice(state)
	return bool(audio.get("spatial_audio_enabled", true))

static func _get_audio_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var slice: Variant = state.get("audio", {})
	if slice is Dictionary:
		return slice as Dictionary
	return {}

