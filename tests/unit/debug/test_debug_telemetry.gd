extends GutTest

# Test suite for U_DebugTelemetry (Phase 2 - TDD RED)
# Tests written BEFORE implementation to drive design

const U_DEBUG_TELEMETRY := preload("res://scripts/managers/helpers/u_debug_telemetry.gd")

func before_each() -> void:
	# Clear session log before each test
	U_DEBUG_TELEMETRY.clear_session_log()

func after_each() -> void:
	# Clean up after each test
	U_DEBUG_TELEMETRY.clear_session_log()

# ==============================================================================
# Log Level Enum Tests
# ==============================================================================

func test_log_level_enum_values() -> void:
	assert_eq(U_DEBUG_TELEMETRY.LogLevel.DEBUG, 0, "DEBUG should be 0")
	assert_eq(U_DEBUG_TELEMETRY.LogLevel.INFO, 1, "INFO should be 1")
	assert_eq(U_DEBUG_TELEMETRY.LogLevel.WARN, 2, "WARN should be 2")
	assert_eq(U_DEBUG_TELEMETRY.LogLevel.ERROR, 3, "ERROR should be 3")

# ==============================================================================
# Log Entry Structure Tests
# ==============================================================================

func test_log_creates_entry_with_required_fields() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test message")
	var log := U_DEBUG_TELEMETRY.get_session_log()

	assert_eq(log.size(), 1, "Should have one log entry")

	var entry: Dictionary = log[0]
	assert_has(entry, "timestamp", "Entry should have timestamp")
	assert_has(entry, "level", "Entry should have level")
	assert_has(entry, "category", "Entry should have category")
	assert_has(entry, "message", "Entry should have message")
	assert_has(entry, "data", "Entry should have data")

func test_log_entry_timestamp_is_float() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_typeof(entry["timestamp"], TYPE_FLOAT, "Timestamp should be float")
	assert_gte(entry["timestamp"], 0.0, "Timestamp should be non-negative")

func test_log_entry_level_is_string() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_typeof(entry["level"], TYPE_STRING, "Level should be string")
	assert_eq(entry["level"], "INFO", "Level should be enum name")

func test_log_entry_category_is_string_name() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("gameplay"), "Test")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	# Dictionary stores StringName as String in some contexts
	assert_true(entry["category"] is StringName or entry["category"] is String, "Category should be StringName or String")
	assert_eq(str(entry["category"]), "gameplay", "Category should match input")

func test_log_entry_message_is_string() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test message")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_typeof(entry["message"], TYPE_STRING, "Message should be string")
	assert_eq(entry["message"], "Test message", "Message should match input")

func test_log_entry_data_defaults_to_empty_dict() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_typeof(entry["data"], TYPE_DICTIONARY, "Data should be dictionary")
	assert_eq(entry["data"].size(), 0, "Data should be empty when not provided")

func test_log_entry_data_contains_custom_fields() -> void:
	var custom_data := {"player_id": "test_player", "damage": 50}
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("gameplay"), "Damage taken", custom_data)
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["data"]["player_id"], "test_player", "Data should contain player_id")
	assert_eq(entry["data"]["damage"], 50, "Data should contain damage")

# ==============================================================================
# Session Log Accumulation Tests
# ==============================================================================

func test_session_log_accumulates_entries_in_order() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "First")
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.WARN, StringName("test"), "Second")
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.ERROR, StringName("test"), "Third")

	var log := U_DEBUG_TELEMETRY.get_session_log()
	assert_eq(log.size(), 3, "Should have 3 entries")
	assert_eq(log[0]["message"], "First", "First entry should be first")
	assert_eq(log[1]["message"], "Second", "Second entry should be second")
	assert_eq(log[2]["message"], "Third", "Third entry should be third")

func test_session_log_timestamps_are_increasing() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "First")
	await get_tree().create_timer(0.01).timeout
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Second")

	var log := U_DEBUG_TELEMETRY.get_session_log()
	assert_gte(log[1]["timestamp"], log[0]["timestamp"], "Timestamps should be non-decreasing")

# ==============================================================================
# Convenience Method Tests
# ==============================================================================

func test_log_debug_convenience_method() -> void:
	U_DEBUG_TELEMETRY.log_debug(StringName("test"), "Debug message")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["level"], "DEBUG", "log_debug should use DEBUG level")
	assert_eq(entry["message"], "Debug message", "Message should match")

func test_log_info_convenience_method() -> void:
	U_DEBUG_TELEMETRY.log_info(StringName("test"), "Info message")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["level"], "INFO", "log_info should use INFO level")
	assert_eq(entry["message"], "Info message", "Message should match")

func test_log_warn_convenience_method() -> void:
	U_DEBUG_TELEMETRY.log_warn(StringName("test"), "Warn message")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["level"], "WARN", "log_warn should use WARN level")
	assert_eq(entry["message"], "Warn message", "Message should match")

func test_log_error_convenience_method() -> void:
	U_DEBUG_TELEMETRY.log_error(StringName("test"), "Error message")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["level"], "ERROR", "log_error should use ERROR level")
	assert_eq(entry["message"], "Error message", "Message should match")

func test_convenience_methods_support_custom_data() -> void:
	U_DEBUG_TELEMETRY.log_info(StringName("test"), "With data", {"key": "value"})
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["data"]["key"], "value", "Convenience methods should support data")

# ==============================================================================
# get_session_log() Tests
# ==============================================================================

func test_get_session_log_returns_array_copy() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Original")

	var log1 := U_DEBUG_TELEMETRY.get_session_log()
	var log2 := U_DEBUG_TELEMETRY.get_session_log()

	# Modify one copy
	log1.append({"modified": true})

	# Other copy should be unaffected
	assert_eq(log2.size(), 1, "Second copy should not be affected by modifications to first")
	assert_false(log2.has({"modified": true}), "Second copy should not contain modifications")

func test_get_session_log_returns_empty_array_initially() -> void:
	var log := U_DEBUG_TELEMETRY.get_session_log()
	assert_eq(log.size(), 0, "Session log should be empty initially")
	assert_typeof(log, TYPE_ARRAY, "Should return array")

# ==============================================================================
# clear_session_log() Tests
# ==============================================================================

func test_clear_session_log_empties_log() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Entry 1")
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Entry 2")

	assert_eq(U_DEBUG_TELEMETRY.get_session_log().size(), 2, "Should have 2 entries before clear")

	U_DEBUG_TELEMETRY.clear_session_log()

	assert_eq(U_DEBUG_TELEMETRY.get_session_log().size(), 0, "Should be empty after clear")

func test_clear_session_log_allows_new_entries() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Old")
	U_DEBUG_TELEMETRY.clear_session_log()
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "New")

	var log := U_DEBUG_TELEMETRY.get_session_log()
	assert_eq(log.size(), 1, "Should have 1 entry after clear + new log")
	assert_eq(log[0]["message"], "New", "Should contain new entry, not old")

# ==============================================================================
# Export Format Tests
# ==============================================================================

func test_get_export_data_structure() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test entry")

	var export_data: Dictionary = U_DEBUG_TELEMETRY.get_export_data()

	assert_has(export_data, "session_start", "Export should have session_start")
	assert_has(export_data, "session_end", "Export should have session_end")
	assert_has(export_data, "build_id", "Export should have build_id")
	assert_has(export_data, "entries", "Export should have entries")

func test_export_data_session_start_is_string() -> void:
	var export_data: Dictionary = U_DEBUG_TELEMETRY.get_export_data()
	assert_typeof(export_data["session_start"], TYPE_STRING, "session_start should be string (ISO timestamp)")

func test_export_data_session_end_is_string() -> void:
	var export_data: Dictionary = U_DEBUG_TELEMETRY.get_export_data()
	assert_typeof(export_data["session_end"], TYPE_STRING, "session_end should be string (ISO timestamp)")

func test_export_data_build_id_is_string() -> void:
	var export_data: Dictionary = U_DEBUG_TELEMETRY.get_export_data()
	assert_typeof(export_data["build_id"], TYPE_STRING, "build_id should be string")

func test_export_data_entries_is_array() -> void:
	var export_data: Dictionary = U_DEBUG_TELEMETRY.get_export_data()
	assert_typeof(export_data["entries"], TYPE_ARRAY, "entries should be array")

func test_export_data_contains_log_entries() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Entry 1")
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.WARN, StringName("test"), "Entry 2")

	var export_data: Dictionary = U_DEBUG_TELEMETRY.get_export_data()
	assert_eq(export_data["entries"].size(), 2, "Export should contain all log entries")
	assert_eq(export_data["entries"][0]["message"], "Entry 1", "First entry should match")
	assert_eq(export_data["entries"][1]["message"], "Entry 2", "Second entry should match")

# ==============================================================================
# Edge Cases
# ==============================================================================

func test_log_handles_empty_message() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["message"], "", "Should handle empty message")

func test_log_handles_empty_category() -> void:
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName(""), "Test")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(str(entry["category"]), "", "Should handle empty category")

func test_log_handles_null_data() -> void:
	# When no data dict is provided, should default to empty dict
	U_DEBUG_TELEMETRY.add_log(U_DEBUG_TELEMETRY.LogLevel.INFO, StringName("test"), "Test")
	var entry: Dictionary = U_DEBUG_TELEMETRY.get_session_log()[0]

	assert_eq(entry["data"].size(), 0, "Should default to empty dict when no data provided")
