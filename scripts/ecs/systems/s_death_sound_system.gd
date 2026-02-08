@icon("res://assets/editor_icons/icn_system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_DeathSoundSystem

## Death Sound System (Phase 6 - Refactored)
##
## Plays death sounds using base class helpers with pause/transition blocking.
## Resolves entity position from entity_id.

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_death_sound_settings.gd")

@export var settings: SETTINGS_TYPE

var _last_play_time: float = -INF

func get_event_name() -> StringName:
	return StringName("entity_death")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	var is_dead_variant: Variant = payload.get("is_dead", false)
	if not bool(is_dead_variant):
		return {}

	return {
		"entity_id": payload.get("entity_id", StringName("")),
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
	var manager := get_manager()
	if manager == null:
		manager = ECS_UTILS.get_manager(self)

	var min_interval: float = max(settings.min_interval, 0.0)
	var now: float = ECS_UTILS.get_current_time()

	for request_variant in requests:
		if _is_throttled(min_interval, now):
			continue

		var request := request_variant as Dictionary
		if request == null:
			continue

		var entity_id_variant: Variant = request.get("entity_id", StringName(""))
		var entity_id := entity_id_variant as StringName
		if entity_id == StringName(""):
			continue

		var position := Vector3.ZERO
		var typed_manager := manager as I_ECSManager
		if typed_manager != null:
			var entity := typed_manager.get_entity_by_id(entity_id) as Node
			var entity_3d := entity as Node3D
			if entity_3d != null and is_instance_valid(entity_3d):
				position = entity_3d.global_position

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
