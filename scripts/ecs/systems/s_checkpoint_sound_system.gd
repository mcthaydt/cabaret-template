@icon("res://resources/editor_icons/system.svg")
extends "res://scripts/ecs/base_event_sfx_system.gd"
class_name S_CheckpointSoundSystem

const SETTINGS_TYPE := preload("res://scripts/ecs/resources/rs_checkpoint_sound_settings.gd")
const SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

@export var settings: SETTINGS_TYPE

var _last_play_time: float = -INF

func get_event_name() -> StringName:
	return StringName("checkpoint_activated")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"spawn_point_id": payload.get("spawn_point_id", StringName("")),
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

		var spawn_point_id_variant: Variant = request.get("spawn_point_id", StringName(""))
		var spawn_point_id := spawn_point_id_variant as StringName
		var position := _resolve_spawn_point_position(spawn_point_id)

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

func _resolve_spawn_point_position(spawn_point_id: StringName) -> Vector3:
	if spawn_point_id == StringName(""):
		return Vector3.ZERO

	var tree := get_tree()
	if tree == null:
		return Vector3.ZERO

	var root: Node = tree.current_scene
	if root == null:
		root = tree.root

	if root == null:
		return Vector3.ZERO

	var node := root.find_child(String(spawn_point_id), true, false) as Node3D
	if node == null or not is_instance_valid(node):
		return Vector3.ZERO

	return node.global_position
