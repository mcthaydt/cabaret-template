@icon("res://assets/editor_icons/icn_system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_LandingSoundSystem

## Landing Sound System (Phase 6 - Refactored)
##
## Plays landing sounds using base class helpers with pause/transition blocking.
## Volume scales with fall speed (5-30 units).

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_landing_sound_settings.gd")

@export var settings: SETTINGS_TYPE

var _last_play_time: float = -INF

func get_event_name() -> StringName:
	return StringName("entity_landed")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	var fall_speed := 0.0
	if payload.has("fall_speed"):
		fall_speed = float(payload.get("fall_speed", 0.0))
	else:
		var vertical_velocity_variant: Variant = payload.get("vertical_velocity", 0.0)
		fall_speed = abs(float(vertical_velocity_variant))

	return {
		"position": payload.get("position", Vector3.ZERO),
		"fall_speed": fall_speed,
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

		var fall_speed_variant: Variant = request.get("fall_speed", 0.0)
		var fall_speed: float = float(fall_speed_variant)
		if fall_speed <= 5.0:
			continue

		var volume_adjustment := _remap_clamped(fall_speed, 5.0, 30.0, -6.0, 0.0)
		var position := _extract_position(request)
		var pitch_scale := _calculate_pitch(settings.pitch_variation)

		_spawn_sfx({
			"audio_stream": stream,
			"position": position,
			"volume_db": settings.volume_db + volume_adjustment,
			"pitch_scale": pitch_scale,
			"bus": "SFX",
		})
		_last_play_time = now

	requests.clear()

func _remap_clamped(value: float, in_min: float, in_max: float, out_min: float, out_max: float) -> float:
	if is_equal_approx(in_min, in_max):
		return out_min
	var t := clampf((value - in_min) / (in_max - in_min), 0.0, 1.0)
	return lerpf(out_min, out_max, t)
