extends GutTest


func test_scene_id_defaults_to_empty() -> void:
	var mapping := RS_SceneAudioMapping.new()
	assert_eq(mapping.scene_id, StringName(""), "Scene ID should default to empty StringName")

func test_music_track_id_defaults_to_empty() -> void:
	var mapping := RS_SceneAudioMapping.new()
	assert_eq(mapping.music_track_id, StringName(""), "Music track ID should default to empty StringName")

func test_ambient_track_id_defaults_to_empty() -> void:
	var mapping := RS_SceneAudioMapping.new()
	assert_eq(mapping.ambient_track_id, StringName(""), "Ambient track ID should default to empty StringName")

func test_can_set_scene_id() -> void:
	var mapping := RS_SceneAudioMapping.new()
	mapping.scene_id = StringName("test_scene")
	assert_eq(mapping.scene_id, StringName("test_scene"), "Should be able to set scene_id")

func test_can_set_music_track_id() -> void:
	var mapping := RS_SceneAudioMapping.new()
	mapping.music_track_id = StringName("test_music")
	assert_eq(mapping.music_track_id, StringName("test_music"), "Should be able to set music_track_id")

func test_can_set_ambient_track_id() -> void:
	var mapping := RS_SceneAudioMapping.new()
	mapping.ambient_track_id = StringName("test_ambient")
	assert_eq(mapping.ambient_track_id, StringName("test_ambient"), "Should be able to set ambient_track_id")

func test_allows_empty_music_track_id() -> void:
	var mapping := RS_SceneAudioMapping.new()
	mapping.scene_id = StringName("scene_with_no_music")
	mapping.music_track_id = StringName("")
	assert_eq(mapping.music_track_id, StringName(""), "Should allow empty music_track_id (scene with no music)")

func test_allows_empty_ambient_track_id() -> void:
	var mapping := RS_SceneAudioMapping.new()
	mapping.scene_id = StringName("scene_with_no_ambient")
	mapping.ambient_track_id = StringName("")
	assert_eq(mapping.ambient_track_id, StringName(""), "Should allow empty ambient_track_id (scene with no ambient)")
