extends GutTest
# Test suite for U_SaveManager static utility
# Tests save/load/delete operations for multi-slot system

const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_SaveEnvelope := preload("res://scripts/state/utils/u_save_envelope.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

# Test data
var _test_state: Dictionary
var _test_slice_configs: Dictionary


func before_each() -> void:
	_cleanup_test_saves()

	# Setup test state
	_test_state = {
		"gameplay": {
			"player_health": 75.0,
			"player_max_health": 100.0,
			"death_count": 3,
			"completed_areas": ["area_1", "area_2"],
			"play_time_seconds": 123.5
		},
		"scene": {
			"current_scene_id": StringName("scn_exterior"),
			"last_checkpoint_id": StringName("cp_house")
		}
	}

	_test_slice_configs = {}


func after_each() -> void:
	_cleanup_test_saves()


func _cleanup_test_saves() -> void:
	# Remove all test save slots
	for i in range(4):
		var path := U_SaveManager.get_manual_slot_path(i) if i > 0 else U_SaveManager.get_auto_slot_path()
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	# Remove legacy save
	var legacy_path := "user://savegame.json"
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)


# ==============================================================================
# Path Resolution Tests
# ==============================================================================

func test_get_manual_slot_path_returns_correct_paths() -> void:
	assert_eq(U_SaveManager.get_manual_slot_path(1), "user://save_slot_1.json")
	assert_eq(U_SaveManager.get_manual_slot_path(2), "user://save_slot_2.json")
	assert_eq(U_SaveManager.get_manual_slot_path(3), "user://save_slot_3.json")


func test_get_manual_slot_path_returns_empty_for_invalid_index() -> void:
	assert_eq(U_SaveManager.get_manual_slot_path(0), "")
	assert_eq(U_SaveManager.get_manual_slot_path(-1), "")
	assert_eq(U_SaveManager.get_manual_slot_path(5), "")  # 4 is now autosave, so 5 is invalid


func test_get_auto_slot_path_returns_slot_4() -> void:
	assert_eq(U_SaveManager.get_auto_slot_path(), "user://save_slot_4.json")


# ==============================================================================
# Save Operation Tests
# ==============================================================================

func test_save_to_slot_creates_file() -> void:
	var err := U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)

	assert_eq(err, OK, "Save should succeed")
	assert_true(FileAccess.file_exists("user://save_slot_1.json"), "Save file should exist")


func test_save_to_slot_stores_correct_metadata() -> void:
	U_SaveManager.save_to_slot(2, _test_state, _test_slice_configs)

	var metadata := U_SaveManager.get_slot_metadata(2)
	assert_not_null(metadata, "Metadata should exist")
	assert_eq(metadata.slot_id, 2)
	assert_gt(metadata.timestamp, 0.0, "Timestamp should be set")
	assert_eq(metadata.scene_id, StringName("scn_exterior"))
	assert_eq(metadata.player_health, 75.0)
	assert_eq(metadata.death_count, 3)
	assert_false(metadata.is_empty)


func test_save_to_auto_slot_marks_as_autosave() -> void:
	U_SaveManager.save_to_auto_slot(_test_state, _test_slice_configs)

	var metadata := U_SaveManager.get_slot_metadata(U_SaveManager.AUTO_SLOT_INDEX)
	assert_not_null(metadata)
	assert_eq(metadata.slot_type, RS_SaveSlotMetadata.SlotType.AUTO)
	assert_eq(metadata.slot_id, U_SaveManager.AUTO_SLOT_INDEX)


func test_save_to_slot_with_invalid_index_zero_fails() -> void:
	var err := U_SaveManager.save_to_slot(0, _test_state, _test_slice_configs)
	assert_push_error("Invalid slot index")
	assert_ne(err, OK, "Save should fail for invalid slot")


func test_save_to_slot_with_invalid_index_out_of_range_fails() -> void:
	var err := U_SaveManager.save_to_slot(5, _test_state, _test_slice_configs)  # 4 is autosave, 5 is invalid
	assert_push_error("Invalid slot index")
	assert_ne(err, OK, "Save should fail for out-of-range slot")


# ==============================================================================
# Load Operation Tests
# ==============================================================================

func test_load_from_slot_restores_state() -> void:
	# Arrange - Save first
	U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)

	# Act - Load into empty state
	var loaded_state := {}
	var err := U_SaveManager.load_from_slot(1, loaded_state, _test_slice_configs)

	# Assert
	assert_eq(err, OK, "Load should succeed")
	assert_eq(loaded_state.get("gameplay").get("player_health"), 75.0)
	assert_eq(loaded_state.get("gameplay").get("death_count"), 3)
	assert_eq(loaded_state.get("scene").get("current_scene_id"), StringName("scn_exterior"))


func test_load_from_nonexistent_slot_fails() -> void:
	var loaded_state := {}
	var err := U_SaveManager.load_from_slot(3, loaded_state, _test_slice_configs)
	assert_push_error("File does not exist")

	assert_ne(err, OK, "Load should fail for empty slot")


func test_load_from_auto_slot_works() -> void:
	# Arrange
	U_SaveManager.save_to_auto_slot(_test_state, _test_slice_configs)

	# Act
	var loaded_state := {}
	var err := U_SaveManager.load_from_auto_slot(loaded_state, _test_slice_configs)

	# Assert
	assert_eq(err, OK)
	assert_eq(loaded_state.get("gameplay").get("player_health"), 75.0)


# ==============================================================================
# Delete Operation Tests
# ==============================================================================

func test_delete_slot_removes_file() -> void:
	# Arrange - Create save
	U_SaveManager.save_to_slot(2, _test_state, _test_slice_configs)
	assert_true(FileAccess.file_exists("user://save_slot_2.json"))

	# Act
	var err := U_SaveManager.delete_slot(2)

	# Assert
	assert_eq(err, OK, "Delete should succeed")
	assert_false(FileAccess.file_exists("user://save_slot_2.json"), "File should be deleted")


func test_delete_nonexistent_slot_succeeds() -> void:
	var err := U_SaveManager.delete_slot(3)
	assert_eq(err, OK, "Delete of empty slot should succeed")


# ==============================================================================
# Metadata Query Tests
# ==============================================================================

func test_get_slot_metadata_returns_null_for_empty_slot() -> void:
	var metadata := U_SaveManager.get_slot_metadata(3)
	assert_null(metadata, "Metadata should be null for empty slot")


func test_get_slot_metadata_returns_data_for_populated_slot() -> void:
	U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)

	var metadata := U_SaveManager.get_slot_metadata(1)
	assert_not_null(metadata)
	assert_eq(metadata.slot_id, 1)
	assert_eq(metadata.player_health, 75.0)


func test_get_all_slots_returns_four_slots() -> void:
	var slots := U_SaveManager.get_all_slots()

	assert_eq(slots.size(), 4, "Should return 3 manual + 1 auto")
	# Slots are now: manual 1, 2, 3, then auto (slot 4)
	assert_eq(slots[0].slot_id, 1)
	assert_eq(slots[1].slot_id, 2)
	assert_eq(slots[2].slot_id, 3)
	assert_eq(slots[3].slot_id, U_SaveManager.AUTO_SLOT_INDEX)
	assert_eq(slots[3].slot_type, RS_SaveSlotMetadata.SlotType.AUTO)


func test_get_all_slots_shows_empty_slots() -> void:
	var slots := U_SaveManager.get_all_slots()

	for slot in slots:
		assert_true(slot.is_empty, "All slots should be empty initially")


func test_get_all_slots_shows_populated_slots() -> void:
	# Create saves
	U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)
	U_SaveManager.save_to_auto_slot(_test_state, _test_slice_configs)

	var slots := U_SaveManager.get_all_slots()

	assert_false(slots[0].is_empty, "Slot 1 should be populated")
	assert_true(slots[1].is_empty, "Slot 2 should be empty")
	assert_true(slots[2].is_empty, "Slot 3 should be empty")
	assert_false(slots[3].is_empty, "Autosave should be populated")


# ==============================================================================
# Most Recent Slot Tests
# ==============================================================================

func test_get_most_recent_slot_returns_newest_save() -> void:
	# Arrange - Create saves with delays
	U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)
	await get_tree().create_timer(0.1).timeout
	U_SaveManager.save_to_slot(2, _test_state, _test_slice_configs)

	# Act
	var most_recent := U_SaveManager.get_most_recent_slot()

	# Assert
	assert_eq(most_recent, 2, "Most recent save should be slot 2")


func test_get_most_recent_slot_returns_negative_when_no_saves() -> void:
	var most_recent := U_SaveManager.get_most_recent_slot()
	assert_lt(most_recent, 0, "Should return negative when no saves exist")


func test_get_most_recent_slot_includes_autosave() -> void:
	# Arrange
	U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)
	await get_tree().create_timer(0.1).timeout
	U_SaveManager.save_to_auto_slot(_test_state, _test_slice_configs)

	# Act
	var most_recent := U_SaveManager.get_most_recent_slot()

	# Assert - Autosave is now slot 4
	assert_eq(most_recent, U_SaveManager.AUTO_SLOT_INDEX, "Autosave should be most recent")


# ==============================================================================
# Has Any Save Tests
# ==============================================================================

func test_has_any_save_returns_false_when_empty() -> void:
	assert_false(U_SaveManager.has_any_save())


func test_has_any_save_returns_true_when_manual_save_exists() -> void:
	U_SaveManager.save_to_slot(1, _test_state, _test_slice_configs)
	assert_true(U_SaveManager.has_any_save())


func test_has_any_save_returns_true_when_autosave_exists() -> void:
	U_SaveManager.save_to_auto_slot(_test_state, _test_slice_configs)
	assert_true(U_SaveManager.has_any_save())


# ==============================================================================
# Integration Tests
# ==============================================================================

func test_save_load_roundtrip_preserves_data() -> void:
	# Arrange
	var original_state := {
		"gameplay": {
			"player_health": 33.5,
			"player_max_health": 100.0,
			"completed_areas": ["area_1", "area_2", "area_3"],
			"death_count": 7,
			"play_time_seconds": 456.7
		},
		"scene": {
			"current_scene_id": StringName("scn_test"),
			"last_checkpoint_id": StringName("cp_test")
		}
	}

	# Act - Save then load
	U_SaveManager.save_to_slot(1, original_state, _test_slice_configs)
	var loaded_state := {}
	U_SaveManager.load_from_slot(1, loaded_state, _test_slice_configs)

	# Assert - Deep comparison
	assert_eq(
		loaded_state.get("gameplay").get("player_health"),
		original_state.get("gameplay").get("player_health")
	)
	assert_eq(
		loaded_state.get("gameplay").get("completed_areas"),
		original_state.get("gameplay").get("completed_areas")
	)
	assert_eq(
		loaded_state.get("gameplay").get("death_count"),
		original_state.get("gameplay").get("death_count")
	)
	assert_eq(
		loaded_state.get("scene").get("current_scene_id"),
		original_state.get("scene").get("current_scene_id")
	)


func test_overwrite_existing_save() -> void:
	# Arrange - Create initial save
	var initial_state := {"gameplay": {"player_health": 50.0}}
	U_SaveManager.save_to_slot(1, initial_state, _test_slice_configs)

	var initial_metadata := U_SaveManager.get_slot_metadata(1)
	var initial_timestamp := initial_metadata.timestamp

	await get_tree().create_timer(1.1).timeout  # Ensure full second passes

	# Act - Overwrite with new state
	var new_state := {"gameplay": {"player_health": 100.0}}
	U_SaveManager.save_to_slot(1, new_state, _test_slice_configs)

	# Assert
	var loaded_state := {}
	U_SaveManager.load_from_slot(1, loaded_state, _test_slice_configs)
	assert_eq(loaded_state.get("gameplay").get("player_health"), 100.0)

	var new_metadata := U_SaveManager.get_slot_metadata(1)
	assert_gt(new_metadata.timestamp, initial_timestamp, "Timestamp should be updated")


func test_multiple_slots_independent() -> void:
	# Arrange - Save different data to different slots
	var state1 := {"gameplay": {"player_health": 25.0}}
	var state2 := {"gameplay": {"player_health": 50.0}}
	var state3 := {"gameplay": {"player_health": 75.0}}

	U_SaveManager.save_to_slot(1, state1, _test_slice_configs)
	U_SaveManager.save_to_slot(2, state2, _test_slice_configs)
	U_SaveManager.save_to_slot(3, state3, _test_slice_configs)

	# Act - Load each
	var loaded1 := {}
	var loaded2 := {}
	var loaded3 := {}
	U_SaveManager.load_from_slot(1, loaded1, _test_slice_configs)
	U_SaveManager.load_from_slot(2, loaded2, _test_slice_configs)
	U_SaveManager.load_from_slot(3, loaded3, _test_slice_configs)

	# Assert
	assert_eq(loaded1.get("gameplay").get("player_health"), 25.0)
	assert_eq(loaded2.get("gameplay").get("player_health"), 50.0)
	assert_eq(loaded3.get("gameplay").get("player_health"), 75.0)
