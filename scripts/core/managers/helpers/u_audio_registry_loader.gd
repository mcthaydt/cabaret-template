class_name U_AudioRegistryLoader
extends RefCounted

## Audio Registry Loader
##
## Centralized registry for all audio resources with O(1) Dictionary lookups.
## Call initialize() once at startup to populate all registries.
## Use add_extension_loader() before initialize() to register demo/mod tracks.


# Static dictionaries for O(1) lookups
static var _music_tracks: Dictionary = {}
static var _ambient_tracks: Dictionary = {}
static var _ui_sounds: Dictionary = {}
static var _scene_audio_map: Dictionary = {}

static var _extension_loaders: Array[Callable] = []

## Register an extension loader callable (e.g. demo tracks). Must be called
## before initialize() so the loader runs when initialize() fires.
static func add_extension_loader(loader: Callable) -> void:
	if not _extension_loaders.has(loader):
		_extension_loaders.append(loader)

## Remove all registered extension loaders (call in test teardown).
static func clear_extension_loaders() -> void:
	_extension_loaders.clear()

## Register a single music track from external code (demo, mods).
static func register_music_track(track: RS_MusicTrackDefinition) -> void:
	if track == null:
		return
	_music_tracks[track.track_id] = track

## Register a single ambient track from external code (demo, mods).
static func register_ambient_track(track: RS_AmbientTrackDefinition) -> void:
	if track == null:
		return
	_ambient_tracks[track.ambient_id] = track

## Register a single UI sound from external code (demo, mods).
static func register_ui_sound(sound: RS_UISoundDefinition) -> void:
	if sound == null:
		return
	_ui_sounds[sound.sound_id] = sound

## Register a single scene audio mapping from external code (demo, mods).
static func register_scene_mapping(mapping: RS_SceneAudioMapping) -> void:
	if mapping == null:
		return
	_scene_audio_map[mapping.scene_id] = mapping

## Initialize all audio registries. Call once at startup.
static func initialize() -> void:
	_register_music_tracks()
	_register_ambient_tracks()
	_register_ui_sounds()
	_register_scene_audio_mappings()
	for loader: Callable in _extension_loaders:
		if loader.is_valid():
			loader.call()
	_validate_registrations()

## Get music track definition by ID (O(1) lookup)
static func get_music_track(track_id: StringName) -> RS_MusicTrackDefinition:
	return _music_tracks.get(track_id, null)

## Get ambient track definition by ID (O(1) lookup)
static func get_ambient_track(ambient_id: StringName) -> RS_AmbientTrackDefinition:
	return _ambient_tracks.get(ambient_id, null)

## Get UI sound definition by ID (O(1) lookup)
static func get_ui_sound(sound_id: StringName) -> RS_UISoundDefinition:
	return _ui_sounds.get(sound_id, null)

## Get scene audio mapping by scene ID (O(1) lookup)
static func get_audio_for_scene(scene_id: StringName) -> RS_SceneAudioMapping:
	return _scene_audio_map.get(scene_id, null)

## Register all music tracks from .tres resources
static func _register_music_tracks() -> void:
	_music_tracks.clear()

	# Load music track resources
	var main_menu := preload("res://resources/core/audio/tracks/music_main_menu.tres") as RS_MusicTrackDefinition
	var pause := preload("res://resources/core/audio/tracks/music_pause.tres") as RS_MusicTrackDefinition
	# Demo tracks loaded by demo-specific registry

	# Register in dictionary
	_music_tracks[StringName("main_menu")] = main_menu
	_music_tracks[StringName("pause")] = pause
	# Demo tracks loaded by demo-specific registry

## Register all ambient tracks from .tres resources
static func _register_ambient_tracks() -> void:
	_ambient_tracks.clear()
	# Demo ambient tracks registered by demo-specific registry via add_extension_loader()

## Register all UI sounds from .tres resources
static func _register_ui_sounds() -> void:
	_ui_sounds.clear()

	# Load UI sound resources
	var focus := preload("res://resources/core/audio/ui/ui_focus.tres") as RS_UISoundDefinition
	var confirm := preload("res://resources/core/audio/ui/ui_confirm.tres") as RS_UISoundDefinition
	var cancel := preload("res://resources/core/audio/ui/ui_cancel.tres") as RS_UISoundDefinition
	var tick := preload("res://resources/core/audio/ui/ui_tick.tres") as RS_UISoundDefinition

	# Register in dictionary
	_ui_sounds[StringName("ui_focus")] = focus
	_ui_sounds[StringName("ui_confirm")] = confirm
	_ui_sounds[StringName("ui_cancel")] = cancel
	_ui_sounds[StringName("ui_tick")] = tick

## Register all scene audio mappings from .tres resources
static func _register_scene_audio_mappings() -> void:
	_scene_audio_map.clear()

	# Load scene mapping resources
	var main_menu := preload("res://resources/core/audio/scene_mappings/scene_main_menu.tres") as RS_SceneAudioMapping
	# Demo scene mappings loaded by demo-specific registry

	# Register in dictionary
	_scene_audio_map[StringName("main_menu")] = main_menu

## Validate registrations and warn about issues
static func _validate_registrations() -> void:
	# Check for missing streams
	for track_id in _music_tracks:
		var track: RS_MusicTrackDefinition = _music_tracks[track_id]
		if track.stream == null:
			push_warning("U_AudioRegistryLoader: Music track '%s' has null stream" % track_id)

	for ambient_id in _ambient_tracks:
		var ambient: RS_AmbientTrackDefinition = _ambient_tracks[ambient_id]
		if ambient.stream == null:
			push_warning("U_AudioRegistryLoader: Ambient track '%s' has null stream" % ambient_id)

	for sound_id in _ui_sounds:
		var sound: RS_UISoundDefinition = _ui_sounds[sound_id]
		if sound.stream == null:
			push_warning("U_AudioRegistryLoader: UI sound '%s' has null stream" % sound_id)

	# Validate scene mappings reference valid tracks
	for scene_id in _scene_audio_map:
		var mapping: RS_SceneAudioMapping = _scene_audio_map[scene_id]
		if not mapping.music_track_id.is_empty() and not _music_tracks.has(mapping.music_track_id):
			push_warning("U_AudioRegistryLoader: Scene '%s' references invalid music track '%s'" % [scene_id, mapping.music_track_id])
		if not mapping.ambient_track_id.is_empty() and not _ambient_tracks.has(mapping.ambient_track_id):
			push_warning("U_AudioRegistryLoader: Scene '%s' references invalid ambient track '%s'" % [scene_id, mapping.ambient_track_id])
