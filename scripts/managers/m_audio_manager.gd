@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_AudioManager

## Audio Manager (Phases 1-2)
##
## Creates the audio bus hierarchy and applies volume/mute settings from the
## Redux audio slice.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const M_SFX_SPAWNER := preload("res://scripts/managers/helpers/m_sfx_spawner.gd")

const _MUSIC_REGISTRY: Dictionary = {
	StringName("main_menu"): {
		"stream": preload("res://resources/audio/music/placeholder_main_menu.ogg"),
		"scene": StringName("main_menu"),
	},
	StringName("gameplay"): {
		"stream": preload("res://resources/audio/music/placeholder_gameplay.ogg"),
		"scene": StringName("gameplay_base"),
	},
	StringName("pause"): {
		"stream": preload("res://resources/audio/music/placeholder_pause.ogg"),
		"scene": StringName(""),  # Not tied to a specific scene
	},
}

var _state_store: I_StateStore = null
var _unsubscribe: Callable

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _inactive_music_player: AudioStreamPlayer
var _current_music_id: StringName = StringName("")
var _pre_pause_music_id: StringName = StringName("")
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_manager")
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), self)

	_state_store = U_STATE_UTILS.try_get_store(self)
	if _state_store == null:
		print_verbose("M_AudioManager: StateStore not found. Audio settings will not be applied.")

	_create_bus_layout()
	_initialize_music_players()
	M_SFX_SPAWNER.initialize(self)

	if _state_store != null:
		_unsubscribe = _state_store.subscribe(_on_state_changed)
		_apply_audio_settings(_state_store.get_state())

func _exit_tree() -> void:
	if _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()
	_state_store = null
	M_SFX_SPAWNER.cleanup()

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

	if _music_player_a != null and is_instance_valid(_music_player_a):
		_music_player_a.stop()
	if _music_player_b != null and is_instance_valid(_music_player_b):
		_music_player_b.stop()

func _create_bus_layout() -> void:
	# Clear existing buses beyond Master (bus 0)
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

	# Create bus hierarchy
	# Master (bus 0) - already exists
	# ├── Music (bus 1)
	# ├── SFX (bus 2)
	# │   ├── UI (bus 3)
	# │   └── Footsteps (bus 4)
	# └── Ambient (bus 5)

	AudioServer.add_bus(1)  # Music
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

	AudioServer.add_bus(2)  # SFX
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_send(2, "Master")

	AudioServer.add_bus(3)  # UI
	AudioServer.set_bus_name(3, "UI")
	AudioServer.set_bus_send(3, "SFX")

	AudioServer.add_bus(4)  # Footsteps
	AudioServer.set_bus_name(4, "Footsteps")
	AudioServer.set_bus_send(4, "SFX")

	AudioServer.add_bus(5)  # Ambient
	AudioServer.set_bus_name(5, "Ambient")
	AudioServer.set_bus_send(5, "Master")

func _initialize_music_players() -> void:
	if _music_player_a == null or not is_instance_valid(_music_player_a):
		_music_player_a = AudioStreamPlayer.new()
		_music_player_a.name = "MusicPlayerA"
		_music_player_a.bus = "Music"
		add_child(_music_player_a)

	if _music_player_b == null or not is_instance_valid(_music_player_b):
		_music_player_b = AudioStreamPlayer.new()
		_music_player_b.name = "MusicPlayerB"
		_music_player_b.bus = "Music"
		add_child(_music_player_b)

	_active_music_player = _music_player_a
	_inactive_music_player = _music_player_b

static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

func play_music(track_id: StringName, duration: float = 1.5) -> void:
	if track_id == _current_music_id:
		return

	if not _MUSIC_REGISTRY.has(track_id):
		push_warning("Audio Manager: Unknown music track '%s'" % String(track_id))
		return

	var music_data: Dictionary = _MUSIC_REGISTRY[track_id]
	var stream := music_data.get("stream") as AudioStream
	if stream == null:
		push_warning("Audio Manager: Music track '%s' has no stream" % String(track_id))
		return

	_crossfade_music(stream, track_id, duration)
	_current_music_id = track_id

func _crossfade_music(new_stream: AudioStream, _track_id: StringName, duration: float) -> void:
	if new_stream == null:
		return

	# Kill existing tween
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	# Swap active/inactive players
	var old_player := _active_music_player
	var new_player := _inactive_music_player
	_active_music_player = new_player
	_inactive_music_player = old_player

	if new_player == null or old_player == null:
		return

	# Start new player at -80dB (silent)
	new_player.stream = new_stream
	new_player.volume_db = -80.0
	new_player.play()

	# Crossfade with cubic easing
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.set_trans(Tween.TRANS_CUBIC)
	_music_tween.set_ease(Tween.EASE_IN_OUT)

	if duration < 0.0:
		duration = 0.0

	# Fade out old player (if playing)
	if old_player.playing:
		_music_tween.tween_property(old_player, "volume_db", -80.0, duration)
		_music_tween.chain().tween_callback(old_player.stop)

	# Fade in new player
	_music_tween.tween_property(new_player, "volume_db", 0.0, duration)

func _stop_music(duration: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if _active_music_player == null:
		return

	if duration < 0.0:
		duration = 0.0

	_music_tween = create_tween()
	_music_tween.tween_property(_active_music_player, "volume_db", -80.0, duration)
	_music_tween.chain().tween_callback(_active_music_player.stop)
	_current_music_id = StringName("")

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	_apply_audio_settings(state)
	_handle_music_actions(action)

func _handle_music_actions(action: Dictionary) -> void:
	if action == null or action.is_empty():
		return

	var action_type: StringName = action.get("type", StringName(""))
	match action_type:
		U_SCENE_ACTIONS.ACTION_TRANSITION_COMPLETED:
			var payload: Dictionary = action.get("payload", {})
			var scene_id: StringName = payload.get("scene_id", StringName(""))
			_change_music_for_scene(scene_id)
		U_NAVIGATION_ACTIONS.ACTION_OPEN_PAUSE:
			_pre_pause_music_id = _current_music_id
			play_music(StringName("pause"), 0.5)
		U_NAVIGATION_ACTIONS.ACTION_CLOSE_PAUSE:
			if _pre_pause_music_id != StringName(""):
				play_music(_pre_pause_music_id, 0.5)
				_pre_pause_music_id = StringName("")
			elif _current_music_id == StringName("pause"):
				_stop_music(0.5)

func _change_music_for_scene(scene_id: StringName) -> void:
	if scene_id == StringName(""):
		return

	var track_id := StringName("")
	for candidate_track_id in _MUSIC_REGISTRY:
		var music_data: Dictionary = _MUSIC_REGISTRY[candidate_track_id]
		if music_data.get("scene", StringName("")) == scene_id:
			track_id = candidate_track_id
			break

	# If paused, only update the "return-to" track and keep pause music playing.
	if _pre_pause_music_id != StringName(""):
		_pre_pause_music_id = track_id
		return

	if track_id != StringName(""):
		play_music(track_id, 2.0)
	elif _current_music_id != StringName(""):
		_stop_music(2.0)

func _apply_audio_settings(state: Dictionary) -> void:
	if state == null:
		return

	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ambient_idx := AudioServer.get_bus_index("Ambient")

	AudioServer.set_bus_volume_db(master_idx, _linear_to_db(U_AUDIO_SELECTORS.get_master_volume(state)))
	AudioServer.set_bus_mute(master_idx, U_AUDIO_SELECTORS.is_master_muted(state))

	AudioServer.set_bus_volume_db(music_idx, _linear_to_db(U_AUDIO_SELECTORS.get_music_volume(state)))
	AudioServer.set_bus_mute(music_idx, U_AUDIO_SELECTORS.is_music_muted(state))

	AudioServer.set_bus_volume_db(sfx_idx, _linear_to_db(U_AUDIO_SELECTORS.get_sfx_volume(state)))
	AudioServer.set_bus_mute(sfx_idx, U_AUDIO_SELECTORS.is_sfx_muted(state))

	AudioServer.set_bus_volume_db(ambient_idx, _linear_to_db(U_AUDIO_SELECTORS.get_ambient_volume(state)))
	AudioServer.set_bus_mute(ambient_idx, U_AUDIO_SELECTORS.is_ambient_muted(state))
