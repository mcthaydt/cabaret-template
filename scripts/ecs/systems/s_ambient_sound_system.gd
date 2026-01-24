@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name S_AmbientSoundSystem

const RS_AMBIENT_SOUND_SETTINGS := preload("res://scripts/ecs/resources/rs_ambient_sound_settings.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

@export var settings: RS_AMBIENT_SOUND_SETTINGS

var _ambient_player_a: AudioStreamPlayer
var _ambient_player_b: AudioStreamPlayer
var _active_ambient_player: AudioStreamPlayer
var _inactive_ambient_player: AudioStreamPlayer
var _current_ambient_id: StringName = StringName("")
var _ambient_tween: Tween
var _state_store
var _unsubscribe: Callable

const _AMBIENT_REGISTRY: Dictionary = {
	StringName("exterior"): {
		"stream": preload("res://assets/audio/ambient/placeholder_exterior.wav"),
		# Scene IDs from u_scene_registry_loader.gd: gameplay_base, exterior
		"scenes": [StringName("gameplay_base"), StringName("exterior")]
	},
	StringName("interior"): {
		"stream": preload("res://assets/audio/ambient/placeholder_interior.wav"),
		# Scene IDs from u_scene_registry_loader.gd: interior_house
		"scenes": [StringName("interior_house"), StringName("interior_test")]
	}
}

func _ready() -> void:
	super._ready()

	# Dual-player setup (mirror music system)
	_ambient_player_a = AudioStreamPlayer.new()
	_ambient_player_a.name = "AmbientPlayerA"
	_ambient_player_a.bus = "Ambient"
	add_child(_ambient_player_a)

	_ambient_player_b = AudioStreamPlayer.new()
	_ambient_player_b.name = "AmbientPlayerB"
	_ambient_player_b.bus = "Ambient"
	add_child(_ambient_player_b)

	_active_ambient_player = _ambient_player_a
	_inactive_ambient_player = _ambient_player_b

	# Subscribe to state changes
	_state_store = U_ServiceLocator.get_service(StringName("state_store"))
	if _state_store != null:
		_unsubscribe = _state_store.subscribe(_on_state_changed)

		# Initialize ambient based on current scene state
		# (transition_completed may have already been dispatched before we subscribed)
		var scene_state: Dictionary = _state_store.get_slice(StringName("scene"))
		var current_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))
		if current_scene_id != StringName(""):
			_change_ambient_for_scene(current_scene_id)

func _exit_tree() -> void:
	if _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()
	_state_store = null

func process_tick(_delta: float) -> void:
	# Ambient system is event-driven, not per-tick
	pass

func _on_state_changed(action: Dictionary, _state: Dictionary) -> void:
	if action.get("type") == StringName("scene/transition_completed"):
		var scene_id: StringName = action.get("payload", {}).get("scene_id", StringName(""))
		_change_ambient_for_scene(scene_id)

func _change_ambient_for_scene(scene_id: StringName) -> void:
	if settings == null or not settings.enabled:
		return

	for ambient_id in _AMBIENT_REGISTRY:
		var ambient_data: Dictionary = _AMBIENT_REGISTRY[ambient_id]
		var scenes := ambient_data["scenes"] as Array
		if scene_id in scenes:
			_play_ambient(ambient_id, 2.0)
			return

	# No ambient for this scene - stop current ambient
	_stop_ambient(2.0)

func _play_ambient(ambient_id: StringName, duration: float) -> void:
	if ambient_id == _current_ambient_id:
		return

	if not _AMBIENT_REGISTRY.has(ambient_id):
		return

	var ambient_data: Dictionary = _AMBIENT_REGISTRY[ambient_id]
	var stream := ambient_data["stream"] as AudioStream

	_crossfade_ambient(stream, ambient_id, duration)
	_current_ambient_id = ambient_id

func _crossfade_ambient(new_stream: AudioStream, _ambient_id: StringName, duration: float) -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()

	var old_player := _active_ambient_player
	var new_player := _inactive_ambient_player
	_active_ambient_player = new_player
	_inactive_ambient_player = old_player

	new_player.stream = new_stream
	new_player.volume_db = -80.0
	new_player.play()

	_ambient_tween = get_tree().create_tween()
	_ambient_tween.set_parallel(true)
	_ambient_tween.set_trans(Tween.TRANS_CUBIC)
	_ambient_tween.set_ease(Tween.EASE_IN_OUT)

	if old_player.playing:
		_ambient_tween.tween_property(old_player, "volume_db", -80.0, duration)
		_ambient_tween.chain().tween_callback(old_player.stop)

	_ambient_tween.tween_property(new_player, "volume_db", 0.0, duration)

func _stop_ambient(duration: float) -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()

	_ambient_tween = get_tree().create_tween()
	_ambient_tween.tween_property(_active_ambient_player, "volume_db", -80.0, duration)
	_ambient_tween.chain().tween_callback(_active_ambient_player.stop)

	_current_ambient_id = StringName("")
