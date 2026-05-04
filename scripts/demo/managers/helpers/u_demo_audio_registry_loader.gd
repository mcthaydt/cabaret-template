class_name U_DemoAudioRegistryLoader
extends RefCounted

## Demo Audio Registry Loader
##
## Registers all demo-specific audio resources (music tracks, ambient tracks,
## and scene mappings) via the core U_AudioRegistryLoader public API.
## Call U_AudioRegistryLoader.add_extension_loader(U_DemoAudioRegistryLoader.initialize)
## before M_AudioManager initializes.

const U_CORE_LOADER := preload("res://scripts/core/managers/helpers/u_audio_registry_loader.gd")


static func initialize() -> void:
	_register_music_tracks()
	_register_ambient_tracks()
	_register_scene_audio_mappings()


static func _register_music_tracks() -> void:
	var demo_room := preload("res://resources/demo/audio/tracks/music_alleyway.tres") as RS_MusicTrackDefinition
	var credits := preload("res://resources/demo/audio/tracks/music_credits.tres") as RS_MusicTrackDefinition
	var bar := preload("res://resources/demo/audio/tracks/music_bar.tres") as RS_MusicTrackDefinition
	var exterior := preload("res://resources/demo/audio/tracks/music_exterior.tres") as RS_MusicTrackDefinition
	var interior := preload("res://resources/demo/audio/tracks/music_interior.tres") as RS_MusicTrackDefinition

	U_CORE_LOADER.register_music_track(demo_room)
	U_CORE_LOADER.register_music_track(credits)
	U_CORE_LOADER.register_music_track(bar)
	U_CORE_LOADER.register_music_track(exterior)
	U_CORE_LOADER.register_music_track(interior)


static func _register_ambient_tracks() -> void:
	var exterior := preload("res://resources/demo/audio/ambient/ambient_exterior.tres") as RS_AmbientTrackDefinition
	var interior := preload("res://resources/demo/audio/ambient/ambient_interior.tres") as RS_AmbientTrackDefinition

	U_CORE_LOADER.register_ambient_track(exterior)
	U_CORE_LOADER.register_ambient_track(interior)


static func _register_scene_audio_mappings() -> void:
	var demo_room := preload("res://resources/demo/audio/scene_mappings/scene_alleyway.tres") as RS_SceneAudioMapping
	var credits := preload("res://resources/demo/audio/scene_mappings/scene_credits.tres") as RS_SceneAudioMapping
	var bar := preload("res://resources/demo/audio/scene_mappings/scene_bar.tres") as RS_SceneAudioMapping
	var interior_house := preload("res://resources/demo/audio/scene_mappings/scene_interior_house.tres") as RS_SceneAudioMapping

	U_CORE_LOADER.register_scene_mapping(demo_room)
	U_CORE_LOADER.register_scene_mapping(credits)
	U_CORE_LOADER.register_scene_mapping(bar)
	U_CORE_LOADER.register_scene_mapping(interior_house)
