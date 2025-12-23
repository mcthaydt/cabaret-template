extends GutTest

const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

func test_to_dictionary_roundtrip_preserves_all_fields() -> void:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id = 2
	metadata.slot_type = RS_SaveSlotMetadata.SlotType.AUTO
	metadata.scene_id = StringName("gameplay_base")
	metadata.scene_name = "Gameplay Base"
	metadata.timestamp = 1700000000
	metadata.formatted_timestamp = "2023-11-14 22:13:20"
	metadata.play_time_seconds = 123.5
	metadata.player_health = 75.0
	metadata.player_max_health = 100.0
	metadata.death_count = 3
	metadata.completed_areas = ["exterior", "interior_house"]
	metadata.completion_percentage = 0.42
	metadata.is_empty = false
	metadata.file_path = "user://savegame_slot_2.json"
	metadata.file_version = 1

	var data := metadata.to_dictionary()

	assert_eq(data.get("slot_id"), 2)
	assert_eq(int(data.get("slot_type")), RS_SaveSlotMetadata.SlotType.AUTO)
	assert_eq(data.get("scene_id"), "gameplay_base")
	assert_eq(data.get("scene_name"), "Gameplay Base")
	assert_eq(int(data.get("timestamp")), 1700000000)
	assert_eq(data.get("formatted_timestamp"), "2023-11-14 22:13:20")
	assert_almost_eq(float(data.get("play_time_seconds")), 123.5, 0.0001)
	assert_almost_eq(float(data.get("player_health")), 75.0, 0.0001)
	assert_almost_eq(float(data.get("player_max_health")), 100.0, 0.0001)
	assert_eq(int(data.get("death_count")), 3)
	assert_eq(data.get("completed_areas"), ["exterior", "interior_house"])
	assert_almost_eq(float(data.get("completion_percentage")), 0.42, 0.0001)
	assert_eq(bool(data.get("is_empty")), false)
	assert_eq(data.get("file_path"), "user://savegame_slot_2.json")
	assert_eq(int(data.get("file_version")), 1)

	var roundtrip := RS_SaveSlotMetadata.new()
	roundtrip.from_dictionary(data)
	assert_eq(roundtrip.slot_id, metadata.slot_id)
	assert_eq(roundtrip.slot_type, metadata.slot_type)
	assert_eq(roundtrip.scene_id, metadata.scene_id)
	assert_eq(roundtrip.scene_name, metadata.scene_name)
	assert_eq(roundtrip.timestamp, metadata.timestamp)
	assert_eq(roundtrip.formatted_timestamp, metadata.formatted_timestamp)
	assert_almost_eq(roundtrip.play_time_seconds, metadata.play_time_seconds, 0.0001)
	assert_almost_eq(roundtrip.player_health, metadata.player_health, 0.0001)
	assert_almost_eq(roundtrip.player_max_health, metadata.player_max_health, 0.0001)
	assert_eq(roundtrip.death_count, metadata.death_count)
	assert_eq(roundtrip.completed_areas, metadata.completed_areas)
	assert_almost_eq(roundtrip.completion_percentage, metadata.completion_percentage, 0.0001)
	assert_eq(roundtrip.is_empty, metadata.is_empty)
	assert_eq(roundtrip.file_path, metadata.file_path)
	assert_eq(roundtrip.file_version, metadata.file_version)

func test_from_dictionary_handles_missing_fields_safely() -> void:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.from_dictionary({
		"scene_id": "gameplay_base"
	})

	assert_eq(metadata.scene_id, StringName("gameplay_base"))
	assert_almost_eq(metadata.completion_percentage, -1.0, 0.0001)
	assert_true(metadata.is_empty)
	assert_eq(metadata.completed_areas, [])

func test_get_display_summary_is_stable_and_non_empty() -> void:
	var empty := RS_SaveSlotMetadata.new()
	assert_eq(empty.get_display_summary(), "Empty")

	var filled := RS_SaveSlotMetadata.new()
	filled.is_empty = false
	filled.scene_name = "Gameplay Base"
	filled.scene_id = StringName("gameplay_base")
	filled.formatted_timestamp = "2023-11-14 22:13:20"
	filled.play_time_seconds = 123.5
	filled.player_health = 75.0
	filled.player_max_health = 100.0
	filled.death_count = 3
	filled.completed_areas = ["exterior"]

	var summary := filled.get_display_summary()
	assert_true(summary.contains("Gameplay Base"))
	assert_true(summary.contains("gameplay_base"))
	assert_true(summary.contains("2023-11-14 22:13:20"))
