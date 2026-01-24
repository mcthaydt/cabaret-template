@icon("res://assets/editor_icons/system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_DeathSoundSystem

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_death_sound_settings.gd")
const SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

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

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	var stream := settings.audio_stream as AudioStream
	if stream == null:
		requests.clear()
		return

	var manager := get_manager()
	if manager == null:
		manager = ECS_UTILS.get_manager(self)

	var min_interval: float = max(settings.min_interval, 0.0)
	var now: float = ECS_UTILS.get_current_time()
	var pitch_variation: float = clampf(settings.pitch_variation, 0.0, 0.95)

	for request_variant in requests:
		if min_interval > 0.0 and now - _last_play_time < min_interval:
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

		var pitch_scale := 1.0
		if pitch_variation > 0.0:
			pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)

		SFX_SPAWNER.spawn_3d({
			"audio_stream": stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": pitch_scale,
			"bus": "SFX",
		})
		_last_play_time = now

	requests.clear()
