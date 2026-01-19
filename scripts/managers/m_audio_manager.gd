@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_AudioManager

## Audio Manager (Phases 1-2)
##
## Creates the audio bus hierarchy and applies volume/mute settings from the
## Redux audio slice.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_AUDIO_ACTIONS := preload("res://scripts/state/actions/u_audio_actions.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_AUDIO_SERIALIZATION := preload("res://scripts/utils/u_audio_serialization.gd")
const M_SFX_SPAWNER := preload("res://scripts/managers/helpers/m_sfx_spawner.gd")

const _MUSIC_REGISTRY: Dictionary = {
	StringName("main_menu"): {
		"stream": preload("res://resources/audio/music/main_menu.mp3"),
		"scenes": [StringName("main_menu")],
	},
	StringName("exterior"): {
		"stream": preload("res://resources/audio/music/exterior.mp3"),
		"scenes": [StringName("exterior")],
	},
	StringName("interior"): {
		"stream": preload("res://resources/audio/music/interior.mp3"),
		"scenes": [StringName("interior_house")],
	},
	StringName("pause"): {
		"stream": preload("res://resources/audio/music/pause.mp3"),
		"scenes": [],  # Not tied to a specific scene
	},
	StringName("credits"): {
		"stream": preload("res://resources/audio/music/credits.mp3"),
		"scenes": [StringName("credits")],
	},
}

const _UI_SOUND_REGISTRY: Dictionary = {
	StringName("ui_focus"): preload("res://resources/audio/sfx/placeholder_ui_focus.wav"),
	StringName("ui_confirm"): preload("res://resources/audio/sfx/placeholder_ui_confirm.wav"),
	StringName("ui_cancel"): preload("res://resources/audio/sfx/placeholder_ui_cancel.wav"),
	StringName("ui_tick"): preload("res://resources/audio/sfx/placeholder_ui_tick.wav"),
}

var _state_store: I_StateStore = null
var _unsubscribe: Callable

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _inactive_music_player: AudioStreamPlayer
var _current_music_id: StringName = StringName("")
var _pre_pause_music_id: StringName = StringName("")
var _pre_pause_music_position: float = 0.0
var _is_pause_overlay_active: bool = false
var _music_tween: Tween

var _ui_player: AudioStreamPlayer
var _audio_settings_preview_active: bool = false
var _audio_save_debounce_scheduled: bool = false
var _loading_persisted_settings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), self)

	_create_bus_layout()
	_initialize_music_players()
	_initialize_ui_player()
	M_SFX_SPAWNER.initialize(self)

	await _initialize_store_async()

func _exit_tree() -> void:
	if _audio_save_debounce_scheduled:
		_flush_pending_audio_save()
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

func _initialize_store_async() -> void:
	var store := await _await_store_ready_soft()
	if store == null:
		print_verbose("M_AudioManager: StateStore not found. Audio settings will not be applied.")
		return

	_state_store = store
	_unsubscribe = _state_store.subscribe(_on_state_changed)

	var applied_persisted := _load_persisted_audio_settings()
	if not applied_persisted:
		_apply_audio_settings(_state_store.get_state())

	# Initialize music based on current scene state
	# (transition_completed may have already been dispatched before we subscribed)
	var scene_state: Dictionary = _state_store.get_slice(StringName("scene"))
	var current_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))
	if current_scene_id != StringName(""):
		_change_music_for_scene(current_scene_id)

func _await_store_ready_soft(max_frames: int = 60) -> I_StateStore:
	var tree := get_tree()
	if tree == null:
		return null

	var frames_waited := 0
	while frames_waited <= max_frames:
		var store := U_STATE_UTILS.try_get_store(self)
		if store != null:
			if store.is_ready():
				return store
			await store.store_ready
			if is_instance_valid(store) and store.is_ready():
				return store
		await tree.process_frame
		frames_waited += 1

	return null

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

func _initialize_ui_player() -> void:
	if _ui_player != null and is_instance_valid(_ui_player):
		return

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = "UI"
	add_child(_ui_player)

func play_ui_sound(sound_id: StringName) -> void:
	if sound_id.is_empty():
		return
	if not _UI_SOUND_REGISTRY.has(sound_id):
		return

	if _ui_player == null or not is_instance_valid(_ui_player):
		_initialize_ui_player()

	var stream := _UI_SOUND_REGISTRY[sound_id] as AudioStream
	if stream == null:
		return

	_ui_player.stream = stream
	_ui_player.play()

static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

func play_music(track_id: StringName, duration: float = 1.5, start_position: float = 0.0) -> void:
	if track_id == _current_music_id:
		return

	if not _MUSIC_REGISTRY.has(track_id):
		push_warning("M_AudioManager: Unknown music track '%s'" % String(track_id))
		return

	var music_data: Dictionary = _MUSIC_REGISTRY[track_id]
	var stream := music_data.get("stream") as AudioStream
	if stream == null:
		push_warning("M_AudioManager: Music track '%s' has no stream" % String(track_id))
		return

	_crossfade_music(stream, track_id, duration, start_position)
	_current_music_id = track_id

func _crossfade_music(new_stream: AudioStream, _track_id: StringName, duration: float, start_position: float) -> void:
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
	if start_position < 0.0:
		start_position = 0.0
	new_player.play(start_position)

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
	if not _audio_settings_preview_active:
		_apply_audio_settings(state)
	_handle_music_actions(action)
	_handle_audio_persistence(action)

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
			if _is_pause_overlay_active:
				return
			_is_pause_overlay_active = true
			_pre_pause_music_id = _current_music_id
			_pre_pause_music_position = 0.0
			if _active_music_player != null and is_instance_valid(_active_music_player) and _active_music_player.playing:
				_pre_pause_music_position = _active_music_player.get_playback_position()
			play_music(StringName("pause"), 0.5)
		U_NAVIGATION_ACTIONS.ACTION_CLOSE_PAUSE:
			if not _is_pause_overlay_active:
				return
			_is_pause_overlay_active = false
			if _pre_pause_music_id != StringName(""):
				play_music(_pre_pause_music_id, 0.5, _pre_pause_music_position)
			elif _current_music_id == StringName("pause"):
				_stop_music(0.5)
			_pre_pause_music_id = StringName("")
			_pre_pause_music_position = 0.0

func _handle_audio_persistence(action: Dictionary) -> void:
	if _loading_persisted_settings:
		return
	if action == null or action.is_empty():
		return

	var action_type: Variant = action.get("type", StringName(""))
	var action_name := String(action_type)
	if action_name.begins_with("audio/"):
		_schedule_audio_save()

func _change_music_for_scene(scene_id: StringName) -> void:
	if scene_id == StringName(""):
		return

	var track_id := StringName("")
	for candidate_track_id in _MUSIC_REGISTRY:
		var music_data: Dictionary = _MUSIC_REGISTRY[candidate_track_id]
		var scenes := music_data.get("scenes", []) as Array
		if scene_id in scenes:
			track_id = candidate_track_id
			break

	# If no track found for this scene, keep current music playing (don't stop)
	# This allows UI navigation (settings, pause menu panels, etc.) to not interrupt music
	if track_id == StringName(""):
		return

	# If transitioning to main_menu, clear pause state (returning to main menu from pause)
	if scene_id == StringName("main_menu") and _is_pause_overlay_active:
		_is_pause_overlay_active = false
		_pre_pause_music_id = StringName("")
		_pre_pause_music_position = 0.0

	# If paused, only update the "return-to" track and keep pause music playing.
	if _is_pause_overlay_active:
		_pre_pause_music_id = track_id
		_pre_pause_music_position = 0.0
		return

	# Change to the new track
	play_music(track_id, 2.0)

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

	M_SFX_SPAWNER.set_spatial_audio_enabled(U_AUDIO_SELECTORS.is_spatial_audio_enabled(state))

func _load_persisted_audio_settings() -> bool:
	var persisted := U_AUDIO_SERIALIZATION.load_settings()
	if persisted.is_empty():
		return false
	_apply_persisted_audio_settings(persisted)
	return true

func _apply_persisted_audio_settings(settings: Dictionary) -> void:
	if _state_store == null:
		return

	_loading_persisted_settings = true

	if settings.has("master_volume"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(float(settings.get("master_volume", 1.0))))
	if settings.has("music_volume"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(float(settings.get("music_volume", 1.0))))
	if settings.has("sfx_volume"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(float(settings.get("sfx_volume", 1.0))))
	if settings.has("ambient_volume"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(float(settings.get("ambient_volume", 1.0))))

	if settings.has("master_muted"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_master_muted(bool(settings.get("master_muted", false))))
	if settings.has("music_muted"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(bool(settings.get("music_muted", false))))
	if settings.has("sfx_muted"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(bool(settings.get("sfx_muted", false))))
	if settings.has("ambient_muted"):
		_state_store.dispatch(U_AUDIO_ACTIONS.set_ambient_muted(bool(settings.get("ambient_muted", false))))

	if settings.has("spatial_audio_enabled"):
		_state_store.dispatch(
			U_AUDIO_ACTIONS.set_spatial_audio_enabled(
				bool(settings.get("spatial_audio_enabled", true))
			)
		)

	_loading_persisted_settings = false

func _schedule_audio_save() -> void:
	if _audio_save_debounce_scheduled:
		return
	_audio_save_debounce_scheduled = true
	call_deferred("_flush_pending_audio_save")

func _flush_pending_audio_save() -> void:
	_audio_save_debounce_scheduled = false
	var snapshot := _get_audio_settings_snapshot()
	if snapshot.is_empty():
		return
	U_AUDIO_SERIALIZATION.save_settings(snapshot)

func _get_audio_settings_snapshot() -> Dictionary:
	if _state_store == null:
		return {}
	var state := _state_store.get_state()
	var audio_variant: Variant = state.get("audio", {})
	if audio_variant is Dictionary:
		return (audio_variant as Dictionary).duplicate(true)
	return {}

func set_audio_settings_preview(preview_settings: Dictionary) -> void:
	if preview_settings == null or preview_settings.is_empty():
		return
	_audio_settings_preview_active = true
	_apply_audio_settings_from_values(
		float(preview_settings.get("master_volume", 1.0)),
		bool(preview_settings.get("master_muted", false)),
		float(preview_settings.get("music_volume", 1.0)),
		bool(preview_settings.get("music_muted", false)),
		float(preview_settings.get("sfx_volume", 1.0)),
		bool(preview_settings.get("sfx_muted", false)),
		float(preview_settings.get("ambient_volume", 1.0)),
		bool(preview_settings.get("ambient_muted", false)),
		bool(preview_settings.get("spatial_audio_enabled", true))
	)

func clear_audio_settings_preview() -> void:
	if not _audio_settings_preview_active:
		return
	_audio_settings_preview_active = false
	if _state_store != null:
		_apply_audio_settings(_state_store.get_state())

func _apply_audio_settings_from_values(
	master_volume: float,
	master_muted: bool,
	music_volume: float,
	music_muted: bool,
	sfx_volume: float,
	sfx_muted: bool,
	ambient_volume: float,
	ambient_muted: bool,
	spatial_audio_enabled: bool
) -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ambient_idx := AudioServer.get_bus_index("Ambient")

	AudioServer.set_bus_volume_db(master_idx, _linear_to_db(clampf(master_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(master_idx, master_muted)

	AudioServer.set_bus_volume_db(music_idx, _linear_to_db(clampf(music_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(music_idx, music_muted)

	AudioServer.set_bus_volume_db(sfx_idx, _linear_to_db(clampf(sfx_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(sfx_idx, sfx_muted)

	AudioServer.set_bus_volume_db(ambient_idx, _linear_to_db(clampf(ambient_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(ambient_idx, ambient_muted)

	M_SFX_SPAWNER.set_spatial_audio_enabled(spatial_audio_enabled)
