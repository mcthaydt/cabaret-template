@icon("res://resources/editor_icons/system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_VictorySoundSystem

const SETTINGS_TYPE := preload("res://scripts/ecs/resources/rs_victory_sound_settings.gd")
const SFX_SPAWNER := preload("res://scripts/managers/helpers/m_sfx_spawner.gd")

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

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	var stream := settings.audio_stream as AudioStream
	if stream == null:
		requests.clear()
		return

	var min_interval: float = max(settings.min_interval, 0.0)
	var now: float = ECS_UTILS.get_current_time()
	var pitch_variation: float = clampf(settings.pitch_variation, 0.0, 0.95)

	for request_variant in requests:
		if min_interval > 0.0 and now - _last_play_time < min_interval:
			continue

		var request := request_variant as Dictionary
		if request == null:
			continue

		var pitch_scale := 1.0
		if pitch_variation > 0.0:
			pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)

		var position_variant: Variant = request.get("position", Vector3.ZERO)
		var position: Vector3 = Vector3.ZERO
		if position_variant is Vector3:
			position = position_variant

		SFX_SPAWNER.spawn_3d({
			"audio_stream": stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": pitch_scale,
			"bus": "SFX",
		})
		_last_play_time = now

	requests.clear()
