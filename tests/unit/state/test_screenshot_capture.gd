extends GutTest

## Unit tests for screenshot capture functionality
##
## Tests the _capture_viewport_screenshot() method in U_SaveManager,
## which is responsible for capturing gameplay screenshots for save slots.
##
## Note: These tests run in headless mode, so they primarily verify
## the early-exit behavior and null safety rather than actual image capture.

const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")

## Test: Headless mode detection returns empty PackedByteArray
##
## Verifies that when running in headless mode (no rendering backend),
## the screenshot capture gracefully returns an empty byte array instead
## of attempting to access unavailable viewport resources.
##
## This is critical for test environments and headless servers.
func test_headless_mode_returns_empty_array() -> void:
	# Act - Call screenshot capture in headless environment
	var result := U_SaveManager._capture_viewport_screenshot()

	# Assert - Should return empty PackedByteArray
	assert_not_null(result, "Result should not be null")
	assert_typeof(result, TYPE_PACKED_BYTE_ARRAY, "Result should be PackedByteArray")
	assert_eq(result.size(), 0, "Screenshot should be empty in headless mode")


## Test: Screenshot capture is null-safe
##
## Verifies that the screenshot capture handles missing viewport/texture
## gracefully without crashing, even when called multiple times.
##
## This prevents crashes when the function is called during edge cases
## (scene transitions, before viewport ready, etc.)
func test_screenshot_capture_is_null_safe() -> void:
	# Act - Call multiple times to verify stability
	var result1 := U_SaveManager._capture_viewport_screenshot()
	var result2 := U_SaveManager._capture_viewport_screenshot()

	# Assert - Both calls should succeed without crashing
	assert_not_null(result1, "First call should return a value")
	assert_not_null(result2, "Second call should return a value")
	assert_eq(result1.size(), 0, "First call should return empty in headless")
	assert_eq(result2.size(), 0, "Second call should return empty in headless")


## Test: Screenshot capture integrated with save operation
##
## Verifies that saving to a slot successfully captures (or skips)
## screenshot data without errors, and that the metadata includes
## a screenshot_data field.
##
## This ensures the screenshot feature integrates properly with the
## save system even in headless mode.
func test_screenshot_integrated_with_save() -> void:
	# Arrange - Create minimal valid state
	var state := {
		"gameplay": {
			"player_health": 100.0,
			"player_max_health": 100.0,
			"death_count": 0
		},
		"scene": {
			"current_scene_id": StringName("test_scene")
		}
	}

	# Act - Save to slot (which calls _capture_viewport_screenshot internally)
	var err := U_SaveManager.save_to_slot(1, state, {})

	# Assert - Save should succeed
	assert_eq(err, OK, "Save should succeed despite headless screenshot")

	# Verify metadata includes screenshot field
	var metadata := U_SaveManager.get_slot_metadata(1)
	assert_not_null(metadata, "Metadata should exist")

	# Metadata is RS_SaveSlotMetadata Resource, access screenshot_data property directly
	assert_not_null(metadata.screenshot_data, "Metadata should have screenshot_data field")
	assert_typeof(metadata.screenshot_data, TYPE_PACKED_BYTE_ARRAY, "screenshot_data should be PackedByteArray")

	# In headless mode, screenshot should be empty
	assert_eq(metadata.screenshot_data.size(), 0, "Screenshot should be empty in headless mode")

	# Cleanup
	U_SaveManager.delete_slot(1)


## Test: Screenshot field present in serialized metadata
##
## Verifies that the screenshot_data field is properly serialized
## to and from the save file, maintaining data integrity even when empty.
##
## This ensures the save format remains consistent whether screenshots
## are captured or skipped.
func test_screenshot_field_serialized_correctly() -> void:
	# Arrange - Create state and save
	var state := {
		"gameplay": {
			"player_health": 75.0,
			"player_max_health": 100.0,
			"death_count": 3
		},
		"scene": {
			"current_scene_id": StringName("gameplay_base")
		}
	}

	U_SaveManager.save_to_slot(2, state, {})

	# Act - Load metadata back
	var metadata := U_SaveManager.get_slot_metadata(2)

	# Assert - Screenshot field should exist and be serializable
	assert_not_null(metadata, "Metadata should load successfully")

	# Metadata is RS_SaveSlotMetadata Resource, access screenshot_data property directly
	assert_not_null(metadata.screenshot_data, "Metadata should include screenshot_data field")
	assert_typeof(metadata.screenshot_data, TYPE_PACKED_BYTE_ARRAY, "screenshot_data should be PackedByteArray")

	# Cleanup
	U_SaveManager.delete_slot(2)


## Test: Screenshot capture doesn't block save operation
##
## Verifies that even if screenshot capture fails or takes time,
## it doesn't prevent the save operation from completing successfully.
##
## This ensures save reliability even if the screenshot feature has issues.
func test_screenshot_failure_does_not_block_save() -> void:
	# Arrange - Create valid state
	var state := {
		"gameplay": {
			"player_health": 50.0,
			"player_max_health": 100.0,
			"death_count": 1
		},
		"scene": {
			"current_scene_id": StringName("test_scene")
		}
	}

	# Act - Perform multiple saves rapidly
	var err1 := U_SaveManager.save_to_slot(1, state, {})
	var err2 := U_SaveManager.save_to_slot(2, state, {})
	var err3 := U_SaveManager.save_to_slot(3, state, {})

	# Assert - All saves should succeed
	assert_eq(err1, OK, "First save should succeed")
	assert_eq(err2, OK, "Second save should succeed")
	assert_eq(err3, OK, "Third save should succeed")

	# All should have metadata with screenshot field
	assert_not_null(U_SaveManager.get_slot_metadata(1), "Slot 1 metadata exists")
	assert_not_null(U_SaveManager.get_slot_metadata(2), "Slot 2 metadata exists")
	assert_not_null(U_SaveManager.get_slot_metadata(3), "Slot 3 metadata exists")

	# Cleanup
	U_SaveManager.delete_slot(1)
	U_SaveManager.delete_slot(2)
	U_SaveManager.delete_slot(3)
