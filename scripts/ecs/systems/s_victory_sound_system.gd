@icon("res://assets/editor_icons/icn_system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_VictorySoundSystem

## Victory Sound System (Phase 6 - Refactored)
##
## Plays victory sounds using base class helpers with pause/transition blocking.

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_victory_sound_settings.gd")

@export var settings: SETTINGS_TYPE

var _last_play_time: float = -INF

func get_event_name() -> StringName:
	return StringName("victory_triggered")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	var position := Vector3.ZERO
	var body := payload.get("body") as Node3D
	if body != null and is_instance_valid(body):
		position = body.global_position
	else:
		var position_variant: Variant = payload.get("position", Vector3.ZERO)
		if position_variant is Vector3:
			position = position_variant

	return {
		"position": position,
	}

func _get_audio_stream() -> AudioStream:
	if settings == null:
		return null
	return settings.audio_stream

func process_tick(__delta: float) -> void:
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
