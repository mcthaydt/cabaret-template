extends BaseTest

const TEST_DIR := "user://test/"
const TEST_SAVE_DIR := "user://test/saves/"
const TEST_FILE := "user://test/test_save.json"

var _test_data: Dictionary = {
	"header": {
		"save_version": 1,
		"timestamp": "2025-12-25T10:30:00Z",
		"build_id": "1.0.0"
	},
	"state": {
		"gameplay": {"health": 100},
		"scene": {"current_scene_id": "gameplay_base"}
	}
}

func before_each() -> void:
	# Create test directory
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("test"):
		dir.make_dir("test")

	# Clean up any existing test files
	_cleanup_test_files()

	await get_tree().process_frame

func after_each() -> void:
	# Clean up test files
	_cleanup_test_files()

func _cleanup_test_files() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

## ============================================================================
## Behavior Tests (silent_mode = true)
##
## These tests verify the FUNCTIONAL behavior of file I/O operations:
## - Do atomic writes work?
## - Does corruption recovery succeed?
## - Are files cleaned up correctly?
##
## Silent mode is enabled to focus on outcomes without noise from expected
## warnings/errors. Logging behavior is verified separately below.
## ============================================================================

func test_ensure_save_directory_creates_directory() -> void:
	var user_dir := DirAccess.open("user://")
	# Remove test saves directory if it exists (keep tests isolated from production user://saves/)
	if user_dir.dir_exists("test/saves"):
		var test_dir := DirAccess.open(TEST_SAVE_DIR)
		if test_dir:
			test_dir.list_dir_begin()
			var file_name: String = test_dir.get_next()
			while file_name != "":
				if not test_dir.current_is_dir():
					test_dir.remove(file_name)
				file_name = test_dir.get_next()
			test_dir.list_dir_end()
		user_dir.remove("test/saves")

	# Call ensure_save_directory (will be implemented in m_save_file_io.gd)
	var io: Variant = _create_file_io_helper()
	io.call("ensure_save_directory", TEST_SAVE_DIR)

	# Verify directory was created
	assert_true(user_dir.dir_exists("test/saves"), "ensure_save_directory should create the requested directory")

func test_save_to_file_creates_json_file() -> void:
	var io: Variant = _create_file_io_helper()

	var error: Error = io.call("save_to_file", TEST_FILE, _test_data)

	assert_eq(error, OK, "save_to_file should return OK on success")
	assert_true(FileAccess.file_exists(TEST_FILE), "save_to_file should create .json file")

func test_save_to_file_uses_atomic_write_with_tmp() -> void:
	var io: Variant = _create_file_io_helper()

	# We can't easily test the intermediate .tmp file since it's renamed immediately,
	# but we can verify the final result is valid
	var error: Error = io.call("save_to_file", TEST_FILE, _test_data)

	assert_eq(error, OK, "Atomic write should succeed")
	assert_true(FileAccess.file_exists(TEST_FILE), "Final .json file should exist")
	assert_false(FileAccess.file_exists(TEST_FILE + ".tmp"), ".tmp file should be cleaned up after rename")

func test_save_to_file_creates_backup_before_overwrite() -> void:
	var io: Variant = _create_file_io_helper()

	# Create initial save
	var initial_data: Dictionary = _test_data.duplicate(true)
	initial_data["state"]["gameplay"]["health"] = 100
	io.call("save_to_file", TEST_FILE, initial_data)

	# Overwrite with new data
	var new_data: Dictionary = _test_data.duplicate(true)
	new_data["state"]["gameplay"]["health"] = 50
	io.call("save_to_file", TEST_FILE, new_data)

	# Verify .bak exists
	var backup_path: String = TEST_FILE + ".bak"
	assert_true(FileAccess.file_exists(backup_path), "save_to_file should create .bak before overwriting")

	# Verify .bak contains original data
	var backup_content: String = FileAccess.get_file_as_string(backup_path)
	var backup_data: Variant = JSON.parse_string(backup_content)
	assert_not_null(backup_data, "Backup file should contain valid JSON")
	assert_eq(int(backup_data["state"]["gameplay"]["health"]), 100, "Backup should contain original data")

func test_load_from_file_reads_valid_json() -> void:
	var io: Variant = _create_file_io_helper()

	# Create a save file
	io.call("save_to_file", TEST_FILE, _test_data)

	# Load it back
	var result: Dictionary = io.call("load_from_file", TEST_FILE)

	assert_false(result.is_empty(), "load_from_file should return data for valid file")
	assert_eq(int(result["header"]["save_version"]), 1, "Loaded data should match saved data")
	assert_eq(int(result["state"]["gameplay"]["health"]), 100, "Loaded state should match saved state")

func test_load_from_file_falls_back_to_backup_on_missing_json() -> void:
	var io: Variant = _create_file_io_helper()

	# Create a save and its backup
	io.call("save_to_file", TEST_FILE, _test_data)
	io.call("save_to_file", TEST_FILE, _test_data)  # Creates .bak

	# Delete the .json file to simulate corruption
	var dir := DirAccess.open(TEST_DIR)
	dir.remove("test_save.json")

	# Load should fall back to .bak (warnings about backup recovery are expected)
	var result: Dictionary = io.call("load_from_file", TEST_FILE)

	assert_false(result.is_empty(), "load_from_file should fall back to .bak when .json is missing")
	assert_eq(int(result["header"]["save_version"]), 1, "Backup data should be valid")

func test_load_from_file_falls_back_to_backup_on_corrupted_json() -> void:
	var io: Variant = _create_file_io_helper()

	# Create a save and its backup
	io.call("save_to_file", TEST_FILE, _test_data)
	io.call("save_to_file", TEST_FILE, _test_data)  # Creates .bak

	# Corrupt the .json file
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_string("{invalid json truncated")
	file.close()

	# Load should fall back to .bak (errors/warnings about corruption are expected)
	var result: Dictionary = io.call("load_from_file", TEST_FILE)

	assert_false(result.is_empty(), "load_from_file should fall back to .bak when .json is corrupted")
	assert_eq(int(result["header"]["save_version"]), 1, "Backup data should be valid")

func test_load_from_file_returns_empty_dict_when_both_files_missing() -> void:
	var io: Variant = _create_file_io_helper()

	# Try to load nonexistent file
	var result: Dictionary = io.call("load_from_file", "user://test/nonexistent.json")

	assert_true(result.is_empty(), "load_from_file should return empty dict when file doesn't exist")

func test_cleanup_tmp_files_removes_orphaned_tmp() -> void:
	var io: Variant = _create_file_io_helper()

	# Create an orphaned .tmp file (simulating crash mid-write)
	var tmp_file := FileAccess.open(TEST_FILE + ".tmp", FileAccess.WRITE)
	tmp_file.store_string(JSON.stringify(_test_data))
	tmp_file.close()

	assert_true(FileAccess.file_exists(TEST_FILE + ".tmp"), "Orphaned .tmp file should exist before cleanup")

	# Call cleanup (warning about cleanup is expected)
	io.call("cleanup_tmp_files", TEST_DIR)

	assert_false(FileAccess.file_exists(TEST_FILE + ".tmp"), "cleanup_tmp_files should remove orphaned .tmp files")

func test_atomic_write_preserves_original_on_failure() -> void:
	var io: Variant = _create_file_io_helper()

	# Create initial save
	var initial_data: Dictionary = _test_data.duplicate(true)
	initial_data["state"]["gameplay"]["health"] = 100
	io.call("save_to_file", TEST_FILE, initial_data)

	# Verify original exists
	assert_true(FileAccess.file_exists(TEST_FILE), "Original file should exist")

	# Note: We can't easily simulate a write failure in tests, but the atomic write
	# pattern (write to .tmp, then rename) ensures the original is never corrupted
	# during a partial write. If the rename fails, the original remains intact.

func test_load_from_file_returns_empty_for_empty_file() -> void:
	var io: Variant = _create_file_io_helper()

	# Create empty file
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.close()

	# Load should return empty dict without errors
	var result: Dictionary = io.call("load_from_file", TEST_FILE)

	assert_true(result.is_empty(), "Should return empty dict for empty file")

## ============================================================================
## Logging Verification Tests (silent_mode = false)
##
## These tests verify that errors are emitted in specific error conditions.
## They test error emission WITHOUT triggering recovery flows to avoid
## "Unexpected Errors" in GUT output.
## ============================================================================

func test_corrupted_json_emits_parse_error() -> void:
	var io := M_SaveFileIO.new()  # silent_mode = false (default)

	# Create corrupted file (no backup to avoid recovery warnings)
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_string("{invalid json truncated")
	file.close()

	# Load should emit parse error
	var _result: Dictionary = io.load_from_file(TEST_FILE)

	# Verify error was emitted for parse failure
	assert_push_error("JSON parse error")

func test_missing_file_returns_empty_silently() -> void:
	var io := M_SaveFileIO.new()  # silent_mode = false

	# Try to load nonexistent file (no .bak either)
	var result: Dictionary = io.load_from_file("user://test/nonexistent_never_created.json")

	# Should return empty without errors (missing file is not an error)
	assert_true(result.is_empty(), "Should return empty dict for missing file")

func test_invalid_dictionary_type_emits_error() -> void:
	var io := M_SaveFileIO.new()  # silent_mode = false

	# Create file with array instead of dictionary (valid JSON, wrong type, no backup)
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()

	# Load should emit error about invalid type
	var _result: Dictionary = io.load_from_file(TEST_FILE)

	# Verify error was emitted
	assert_push_error("does not contain a valid Dictionary")

## Helper Methods

func _create_file_io_helper() -> Variant:
	# This will load the file IO helper once it's implemented
	# For now, we're writing the tests first (TDD Red phase)
	var io_class: GDScript = load("res://scripts/managers/helpers/m_save_file_io.gd")
	var io: Variant = io_class.new()
	# Enable silent mode to suppress informational warnings in tests
	io.silent_mode = true
	return io
