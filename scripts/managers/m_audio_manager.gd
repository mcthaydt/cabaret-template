@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_audio_manager.gd"
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
const U_SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")
const U_AUDIO_REGISTRY_LOADER := preload("res://scripts/managers/helpers/u_audio_registry_loader.gd")
const U_AUDIO_BUS_CONSTANTS := preload("res://scripts/managers/helpers/u_audio_bus_constants.gd")
const U_CrossfadePlayer := preload("res://scripts/managers/helpers/u_crossfade_player.gd")

const UI_SOUND_POLYPHONY := 4

var _state_store: I_StateStore = null
var _unsubscribe: Callable

var _music_crossfader: U_CrossfadePlayer
var _ambient_crossfader: U_CrossfadePlayer
var _pre_pause_music_id: StringName = StringName("")
var _pre_pause_music_position: float = 0.0
var _is_pause_overlay_active: bool = false

var _ui_sound_players: Array[AudioStreamPlayer] = []
var _ui_sound_index: int = 0
var _audio_settings_preview_active: bool = false
var _audio_save_debounce_scheduled: bool = false
var _loading_persisted_settings: bool = false
var _last_audio_hash: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), self)

	if not U_AUDIO_BUS_CONSTANTS.validate_bus_layout():
		push_error("M_AudioManager: Invalid audio bus layout. Please configure buses in Project Settings → Audio → Buses")

	U_AUDIO_REGISTRY_LOADER.initialize()
	_music_crossfader = U_CrossfadePlayer.new(self, &"Music")
	_ambient_crossfader = U_CrossfadePlayer.new(self, &"Ambient")
	_setup_ui_sound_players()
	U_SFX_SPAWNER.initialize(self)

	await _initialize_store_async()

func _exit_tree() -> void:
	if _audio_save_debounce_scheduled:
		_flush_pending_audio_save()
	if _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()
	_state_store = null
	U_SFX_SPAWNER.cleanup()

	if _music_crossfader != null:
		_music_crossfader.cleanup()
		_music_crossfader = null

	if _ambient_crossfader != null:
		_ambient_crossfader.cleanup()
		_ambient_crossfader = null

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

	# Initialize audio based on current scene state
	# (transition_completed may have already been dispatched before we subscribed)
	var scene_state: Dictionary = _state_store.get_slice(StringName("scene"))
	var current_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))
	if current_scene_id != StringName(""):
		_change_audio_for_scene(current_scene_id)

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

func _setup_ui_sound_players() -> void:
	_ui_sound_players.clear()
	for i in range(UI_SOUND_POLYPHONY):
		var player := AudioStreamPlayer.new()
		player.name = "UIPlayer_%d" % i
		player.bus = "UI"
		add_child(player)
		_ui_sound_players.append(player)

## Override: I_AudioManager.play_ui_sound
func play_ui_sound(sound_id: StringName) -> void:
	if sound_id.is_empty():
		return

	var sound_def := U_AUDIO_REGISTRY_LOADER.get_ui_sound(sound_id)
	if sound_def == null:
		return

	var stream := sound_def.stream
	if stream == null:
		return

	# Use round-robin player selection
	if _ui_sound_players.is_empty():
		_setup_ui_sound_players()

	var player := _ui_sound_players[_ui_sound_index]
	_ui_sound_index = (_ui_sound_index + 1) % UI_SOUND_POLYPHONY

	# Apply sound definition settings
	player.stream = stream
	player.volume_db = sound_def.volume_db

	# Apply pitch variation (randomized within range)
	if sound_def.pitch_variation > 0.0:
		var variation := clampf(sound_def.pitch_variation, 0.0, 0.95)
		player.pitch_scale = randf_range(1.0 - variation, 1.0 + variation)
	else:
		player.pitch_scale = 1.0

	player.play()

static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

## Override: I_AudioManager.play_music
func play_music(track_id: StringName, duration: float = 1.5, start_position: float = 0.0) -> void:
	if _music_crossfader == null:
		return

	if track_id == _music_crossfader.get_current_track_id():
		return

	var track_def := U_AUDIO_REGISTRY_LOADER.get_music_track(track_id)
	if track_def == null:
		push_warning("M_AudioManager: Unknown music track '%s'" % String(track_id))
		return

	var stream := track_def.stream
	if stream == null:
		push_warning("M_AudioManager: Music track '%s' has no stream" % String(track_id))
		return

	_music_crossfader.crossfade_to(stream, track_id, duration, start_position)

## Override: I_AudioManager.stop_music
func stop_music(duration: float = 1.5) -> void:
	if _music_crossfader == null:
		return

	_music_crossfader.stop(duration)

## Override: I_AudioManager.play_ambient
func play_ambient(ambient_id: StringName, duration: float = 2.0) -> void:
	if _ambient_crossfader == null:
		return

	if ambient_id == _ambient_crossfader.get_current_track_id():
		return

	var ambient_def := U_AUDIO_REGISTRY_LOADER.get_ambient_track(ambient_id)
	if ambient_def == null:
		push_warning("M_AudioManager: Unknown ambient track '%s'" % String(ambient_id))
		return

	var stream := ambient_def.stream
	if stream == null:
		push_warning("M_AudioManager: Ambient track '%s' has no stream" % String(ambient_id))
		return

	_ambient_crossfader.crossfade_to(stream, ambient_id, duration)

## Override: I_AudioManager.stop_ambient
func stop_ambient(duration: float = 2.0) -> void:
	if _ambient_crossfader == null:
		return

	_ambient_crossfader.stop(duration)

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	# Phase 9: Hash-based optimization - only apply audio settings when slice changes
	if not _audio_settings_preview_active:
		var audio_slice: Variant = state.get("audio", {})
		if audio_slice is Dictionary:
			var audio_hash := (audio_slice as Dictionary).hash()
			if audio_hash != _last_audio_hash:
				_apply_audio_settings(state)
				_last_audio_hash = audio_hash

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
			_change_audio_for_scene(scene_id)
		U_NAVIGATION_ACTIONS.ACTION_OPEN_PAUSE:
			if _is_pause_overlay_active or _music_crossfader == null:
				return
			_is_pause_overlay_active = true
			_pre_pause_music_id = _music_crossfader.get_current_track_id()
			_pre_pause_music_position = 0.0
			if _music_crossfader.is_playing():
				_pre_pause_music_position = _music_crossfader.get_playback_position()
			play_music(StringName("pause"), 0.5)
		U_NAVIGATION_ACTIONS.ACTION_CLOSE_PAUSE:
			if not _is_pause_overlay_active or _music_crossfader == null:
				return
			_is_pause_overlay_active = false
			if _pre_pause_music_id != StringName(""):
				play_music(_pre_pause_music_id, 0.5, _pre_pause_music_position)
			elif _music_crossfader.get_current_track_id() == StringName("pause"):
				stop_music(0.5)
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

func _change_audio_for_scene(scene_id: StringName) -> void:
	if scene_id == StringName(""):
		return

	var scene_mapping := U_AUDIO_REGISTRY_LOADER.get_audio_for_scene(scene_id)
	if scene_mapping == null:
		# No mapping for this scene, keep current audio playing
		return

	# Handle music
	var music_track_id := scene_mapping.music_track_id
	# If no track found for this scene, keep current music playing (don't stop)
	# This allows UI navigation (settings, pause menu panels, etc.) to not interrupt music
	if music_track_id != StringName("") and not music_track_id.is_empty():
		# If transitioning to main_menu, clear pause state (returning to main menu from pause)
		if scene_id == StringName("main_menu") and _is_pause_overlay_active:
			_is_pause_overlay_active = false
			_pre_pause_music_id = StringName("")
			_pre_pause_music_position = 0.0

		# If paused, only update the "return-to" track and keep pause music playing.
		if _is_pause_overlay_active:
			_pre_pause_music_id = music_track_id
			_pre_pause_music_position = 0.0
		else:
			# Change to the new music track
			play_music(music_track_id, 2.0)

	# Handle ambient
	var ambient_track_id := scene_mapping.ambient_track_id
	if ambient_track_id != StringName("") and not ambient_track_id.is_empty():
		# Crossfade to the new ambient track
		play_ambient(ambient_track_id, 2.0)
	elif _ambient_crossfader != null and _ambient_crossfader.is_playing():
		# No ambient for this scene - stop current ambient
		stop_ambient(2.0)

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

	U_SFX_SPAWNER.set_spatial_audio_enabled(U_AUDIO_SELECTORS.is_spatial_audio_enabled(state))

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

## Override: I_AudioManager.set_audio_settings_preview
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

## Override: I_AudioManager.clear_audio_settings_preview
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

	U_SFX_SPAWNER.set_spatial_audio_enabled(spatial_audio_enabled)
