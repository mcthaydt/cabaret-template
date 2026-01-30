extends GutTest

const RS_MusicTrackDefinition := preload("res://scripts/ecs/resources/rs_music_track_definition.gd")

func test_default_fade_duration_is_1_5() -> void:
	var definition := RS_MusicTrackDefinition.new()
	assert_almost_eq(definition.default_fade_duration, 1.5, 0.0001, "Default fade duration should be 1.5 seconds")

func test_base_volume_offset_db_defaults_to_0() -> void:
	var definition := RS_MusicTrackDefinition.new()
	assert_almost_eq(definition.base_volume_offset_db, 0.0, 0.0001, "Base volume offset should default to 0.0 dB")

func test_loop_defaults_to_true() -> void:
	var definition := RS_MusicTrackDefinition.new()
	assert_true(definition.loop, "Loop should default to true")

func test_pause_behavior_defaults_to_pause() -> void:
	var definition := RS_MusicTrackDefinition.new()
	assert_eq(definition.pause_behavior, "pause", "Pause behavior should default to 'pause'")

func test_can_set_track_id() -> void:
	var definition := RS_MusicTrackDefinition.new()
	definition.track_id = StringName("test_track")
	assert_eq(definition.track_id, StringName("test_track"), "Should be able to set track_id")

func test_can_set_custom_fade_duration() -> void:
	var definition := RS_MusicTrackDefinition.new()
	definition.default_fade_duration = 2.5
	assert_almost_eq(definition.default_fade_duration, 2.5, 0.0001, "Should be able to set custom fade duration")

func test_pause_behavior_accepts_duck() -> void:
	var definition := RS_MusicTrackDefinition.new()
	definition.pause_behavior = "duck"
	assert_eq(definition.pause_behavior, "duck", "Should accept 'duck' pause behavior")

func test_pause_behavior_accepts_continue() -> void:
	var definition := RS_MusicTrackDefinition.new()
	definition.pause_behavior = "continue"
	assert_eq(definition.pause_behavior, "continue", "Should accept 'continue' pause behavior")
