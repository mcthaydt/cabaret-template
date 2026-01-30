@icon("res://assets/editor_icons/icn_system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_JumpSoundSystem

## Jump Sound System (Phase 6 - Refactored)
##
## Plays jump sounds using base class helpers with pause/transition blocking.

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_jump_sound_settings.gd")

@export var settings: SETTINGS_TYPE

var _last_play_time: float = -INF

## Alias for EventSFXSystem.requests to maintain backward compatibility
var play_requests: Array:
	get:
		return requests

func get_event_name() -> StringName:
	return StringName("entity_jumped")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"entity": payload.get("entity", null),
		"position": payload.get("position", Vector3.ZERO),
		"jump_time": payload.get("jump_time", 0.0),
		"jump_force": payload.get("jump_force", 0.0),
		"supported": payload.get("supported", false),
	}

func _get_audio_stream() -> AudioStream:
	if settings == null:
		return null
	return settings.audio_stream

func process_tick(_delta: float) -> void:
	# Phase 6: Use shared helpers from base class
	if _should_skip_processing():
		return

	if _is_audio_blocked():
		requests.clear()
		return

	var stream := _get_audio_stream()
	var min_interval: float = max(settings.min_interval, 0.0)
	var now: float = ECS_UTILS.get_current_time()

	for request_variant in requests:
		if _is_throttled(min_interval, now):
			continue

		var request := request_variant as Dictionary
		if request == null:
			continue

		var position := _extract_position(request)
		var pitch_scale := _calculate_pitch(settings.pitch_variation)

		_spawn_sfx({
			"audio_stream": stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": pitch_scale,
			"bus": "SFX",
		})
		_last_play_time = now

	requests.clear()
