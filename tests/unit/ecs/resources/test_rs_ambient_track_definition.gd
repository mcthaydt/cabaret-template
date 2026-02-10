extends GutTest


func test_default_fade_duration_is_2_0() -> void:
	var definition := RS_AmbientTrackDefinition.new()
	assert_almost_eq(definition.default_fade_duration, 2.0, 0.0001, "Default fade duration should be 2.0 seconds")

func test_base_volume_offset_db_defaults_to_0() -> void:
	var definition := RS_AmbientTrackDefinition.new()
	assert_almost_eq(definition.base_volume_offset_db, 0.0, 0.0001, "Base volume offset should default to 0.0 dB")

func test_loop_defaults_to_true() -> void:
	var definition := RS_AmbientTrackDefinition.new()
	assert_true(definition.loop, "Loop should default to true")

func test_can_set_ambient_id() -> void:
	var definition := RS_AmbientTrackDefinition.new()
	definition.ambient_id = StringName("test_ambient")
	assert_eq(definition.ambient_id, StringName("test_ambient"), "Should be able to set ambient_id")

func test_can_set_custom_fade_duration() -> void:
	var definition := RS_AmbientTrackDefinition.new()
	definition.default_fade_duration = 3.0
	assert_almost_eq(definition.default_fade_duration, 3.0, 0.0001, "Should be able to set custom fade duration")
