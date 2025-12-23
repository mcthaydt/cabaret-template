extends GutTest

## Unit tests for UI_SaveSlotSelector logic methods
##
## Tests pure logic methods that don't require scene nodes.
## Full UI integration tested in tests/integration/save_manager/

const UI_SaveSlotSelector := preload("res://scripts/ui/ui_save_slot_selector.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

var _overlay: UI_SaveSlotSelector


func before_each() -> void:
	_overlay = UI_SaveSlotSelector.new()


func after_each() -> void:
	if is_instance_valid(_overlay):
		_overlay.free()
	_overlay = null


## Test: Mode enum values are distinct
func test_mode_enum_values_are_distinct() -> void:
	assert_ne(UI_SaveSlotSelector.Mode.SAVE, UI_SaveSlotSelector.Mode.LOAD, "SAVE and LOAD modes should have different values")
	assert_eq(UI_SaveSlotSelector.Mode.SAVE, 0, "SAVE mode should be 0")
	assert_eq(UI_SaveSlotSelector.Mode.LOAD, 1, "LOAD mode should be 1")


## Test: Play time formatting - zero seconds
func test_format_play_time_zero_seconds() -> void:
	var result := _overlay._format_play_time(0.0)
	assert_eq(result, "00:00:00", "Zero seconds should format as 00:00:00")


## Test: Play time formatting - one minute
func test_format_play_time_one_minute() -> void:
	var result := _overlay._format_play_time(65.0)
	assert_eq(result, "00:01:05", "65 seconds should format as 00:01:05")


## Test: Play time formatting - one hour
func test_format_play_time_one_hour() -> void:
	var result := _overlay._format_play_time(3661.0)
	assert_eq(result, "01:01:01", "3661 seconds should format as 01:01:01")


## Test: Play time formatting - two hours
func test_format_play_time_two_hours() -> void:
	var result := _overlay._format_play_time(7200.0)
	assert_eq(result, "02:00:00", "7200 seconds should format as 02:00:00")


## Test: Play time formatting - large value
func test_format_play_time_large_value() -> void:
	var result := _overlay._format_play_time(36000.0)  # 10 hours
	assert_eq(result, "10:00:00", "36000 seconds should format as 10:00:00")


## Test: Screenshot cache is initialized empty
func test_screenshot_cache_initialized_empty() -> void:
	assert_eq(_overlay._screenshot_cache.size(), 0, "Screenshot cache should start empty")


## Test: Slot metadata array is initialized empty
func test_slot_metadata_initialized_empty() -> void:
	assert_eq(_overlay._slot_metadata.size(), 0, "Slot metadata array should start empty")


## Test: Mode defaults to LOAD
func test_mode_defaults_to_load() -> void:
	assert_eq(_overlay._mode, UI_SaveSlotSelector.Mode.LOAD, "Default mode should be LOAD")


## Test: Selected slot index defaults to 0
func test_selected_slot_index_defaults_to_zero() -> void:
	assert_eq(_overlay._selected_slot_index, 0, "Default selected slot should be 0")


## Test: Operation tracking flags default to false
func test_operation_flags_default_to_false() -> void:
	assert_false(_overlay._was_saving, "_was_saving should default to false")
	assert_false(_overlay._was_deleting, "_was_deleting should default to false")
