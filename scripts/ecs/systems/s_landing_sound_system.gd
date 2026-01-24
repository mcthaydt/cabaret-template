@icon("res://assets/editor_icons/system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_LandingSoundSystem

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_landing_sound_settings.gd")
const SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

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

		var fall_speed_variant: Variant = request.get("fall_speed", 0.0)
		var fall_speed: float = float(fall_speed_variant)
		if fall_speed <= 5.0:
			continue

		var volume_adjustment := _remap_clamped(fall_speed, 5.0, 30.0, -6.0, 0.0)

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
