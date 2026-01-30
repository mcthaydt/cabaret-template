extends GutTest

const U_AudioRegistryLoader := preload("res://scripts/managers/helpers/u_audio_registry_loader.gd")

func before_each() -> void:
	# Clear static dictionaries before each test
	U_AudioRegistryLoader._music_tracks.clear()
	U_AudioRegistryLoader._ambient_tracks.clear()
	U_AudioRegistryLoader._ui_sounds.clear()
	U_AudioRegistryLoader._scene_audio_map.clear()

func test_initialize_populates_music_tracks() -> void:
	U_AudioRegistryLoader.initialize()
	assert_gt(U_AudioRegistryLoader._music_tracks.size(), 0, "Should populate music tracks")

func test_initialize_populates_ambient_tracks() -> void:
	U_AudioRegistryLoader.initialize()
	assert_gt(U_AudioRegistryLoader._ambient_tracks.size(), 0, "Should populate ambient tracks")

func test_initialize_populates_ui_sounds() -> void:
	U_AudioRegistryLoader.initialize()
	assert_gt(U_AudioRegistryLoader._ui_sounds.size(), 0, "Should populate UI sounds")

func test_initialize_populates_scene_audio_map() -> void:
	U_AudioRegistryLoader.initialize()
	assert_gt(U_AudioRegistryLoader._scene_audio_map.size(), 0, "Should populate scene audio mappings")

func test_get_music_track_returns_definition() -> void:
	U_AudioRegistryLoader.initialize()
	var track = U_AudioRegistryLoader.get_music_track(StringName("main_menu"))
	assert_not_null(track, "Should return music track definition for main_menu")

func test_get_music_track_returns_null_for_invalid_id() -> void:
	U_AudioRegistryLoader.initialize()
	var track = U_AudioRegistryLoader.get_music_track(StringName("invalid_track"))
	assert_null(track, "Should return null for invalid track ID")

func test_get_ambient_track_returns_definition() -> void:
	U_AudioRegistryLoader.initialize()
	var ambient = U_AudioRegistryLoader.get_ambient_track(StringName("exterior"))
	assert_not_null(ambient, "Should return ambient track definition for exterior")

func test_get_ambient_track_returns_null_for_invalid_id() -> void:
	U_AudioRegistryLoader.initialize()
	var ambient = U_AudioRegistryLoader.get_ambient_track(StringName("invalid_ambient"))
	assert_null(ambient, "Should return null for invalid ambient ID")

func test_get_ui_sound_returns_definition() -> void:
	U_AudioRegistryLoader.initialize()
	var sound = U_AudioRegistryLoader.get_ui_sound(StringName("ui_confirm"))
	assert_not_null(sound, "Should return UI sound definition for ui_confirm")

func test_get_ui_sound_returns_null_for_invalid_id() -> void:
	U_AudioRegistryLoader.initialize()
	var sound = U_AudioRegistryLoader.get_ui_sound(StringName("invalid_sound"))
	assert_null(sound, "Should return null for invalid sound ID")

func test_get_audio_for_scene_returns_mapping() -> void:
	U_AudioRegistryLoader.initialize()
	var mapping = U_AudioRegistryLoader.get_audio_for_scene(StringName("main_menu"))
	assert_not_null(mapping, "Should return scene audio mapping for main_menu")

func test_get_audio_for_scene_returns_null_for_invalid_scene() -> void:
	U_AudioRegistryLoader.initialize()
	var mapping = U_AudioRegistryLoader.get_audio_for_scene(StringName("invalid_scene"))
	assert_null(mapping, "Should return null for invalid scene ID")

func test_music_track_has_correct_structure() -> void:
	U_AudioRegistryLoader.initialize()
	var track = U_AudioRegistryLoader.get_music_track(StringName("main_menu"))
	assert_not_null(track.track_id, "Track should have track_id")
	assert_not_null(track.stream, "Track should have stream")

func test_ambient_track_has_correct_structure() -> void:
	U_AudioRegistryLoader.initialize()
	var ambient = U_AudioRegistryLoader.get_ambient_track(StringName("exterior"))
	assert_not_null(ambient.ambient_id, "Ambient should have ambient_id")
	assert_not_null(ambient.stream, "Ambient should have stream")

func test_ui_sound_has_correct_structure() -> void:
	U_AudioRegistryLoader.initialize()
	var sound = U_AudioRegistryLoader.get_ui_sound(StringName("ui_confirm"))
	assert_not_null(sound.sound_id, "Sound should have sound_id")
	assert_not_null(sound.stream, "Sound should have stream")

func test_scene_mapping_has_correct_structure() -> void:
	U_AudioRegistryLoader.initialize()
	var mapping = U_AudioRegistryLoader.get_audio_for_scene(StringName("main_menu"))
	assert_not_null(mapping.scene_id, "Mapping should have scene_id")
	# Note: music_track_id and ambient_track_id fields exist (can be empty StringNames)
	assert_eq(mapping.music_track_id, StringName("main_menu"), "Should have music_track_id field")
	# ambient_track_id can be empty for main_menu scene
	assert_true(mapping.ambient_track_id is StringName, "Should have ambient_track_id field")
