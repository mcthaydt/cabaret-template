extends GutTest


func test_volume_db_defaults_to_0() -> void:
	var definition := RS_UISoundDefinition.new()
	assert_almost_eq(definition.volume_db, 0.0, 0.0001, "Volume should default to 0.0 dB")

func test_pitch_variation_defaults_to_0() -> void:
	var definition := RS_UISoundDefinition.new()
	assert_almost_eq(definition.pitch_variation, 0.0, 0.0001, "Pitch variation should default to 0.0")

func test_throttle_ms_defaults_to_0() -> void:
	var definition := RS_UISoundDefinition.new()
	assert_eq(definition.throttle_ms, 0, "Throttle should default to 0 (no throttle)")

func test_can_set_sound_id() -> void:
	var definition := RS_UISoundDefinition.new()
	definition.sound_id = StringName("test_sound")
	assert_eq(definition.sound_id, StringName("test_sound"), "Should be able to set sound_id")

func test_can_set_custom_volume() -> void:
	var definition := RS_UISoundDefinition.new()
	definition.volume_db = -6.0
	assert_almost_eq(definition.volume_db, -6.0, 0.0001, "Should be able to set custom volume")

func test_can_set_pitch_variation() -> void:
	var definition := RS_UISoundDefinition.new()
	definition.pitch_variation = 0.1
	assert_almost_eq(definition.pitch_variation, 0.1, 0.0001, "Should be able to set pitch variation")

func test_can_set_throttle() -> void:
	var definition := RS_UISoundDefinition.new()
	definition.throttle_ms = 100
	assert_eq(definition.throttle_ms, 100, "Should be able to set throttle to 100ms")
