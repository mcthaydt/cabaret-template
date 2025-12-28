## Shared test utilities for save system tests
## Provides common directory setup/cleanup functions to avoid duplication
class_name U_SaveTestUtils
extends RefCounted

## Standard test directory paths
const TEST_DIR := "user://test/"
const TEST_SAVE_DIR := "user://test_saves/"

## Setup test environment - creates test directories and ensures they're clean
static func setup(save_dir: String = TEST_SAVE_DIR) -> void:
	ensure_directory_clean(save_dir)

## Teardown test environment - removes all test files
static func teardown(save_dir: String = TEST_SAVE_DIR) -> void:
	cleanup_test_files(save_dir)

## Ensure test directory exists and is clean
static func ensure_directory_clean(save_dir: String) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("U_SaveTestUtils: Failed to open user:// directory")
		return

	# Extract directory name from path (e.g., "user://test_saves/" -> "test_saves")
	var dir_name: String = save_dir.replace("user://", "").trim_suffix("/")

	# Create directory if it doesn't exist
	if not dir.dir_exists(dir_name):
		var err := DirAccess.make_dir_recursive_absolute(save_dir)
		if err != OK:
			push_error("U_SaveTestUtils: Failed to create directory: %s (error %d)" % [save_dir, err])
			return

	# Clean existing files
	cleanup_test_files(save_dir)

## Remove all save-related test files from the specified directory
static func cleanup_test_files(save_dir: String) -> void:
	var dir := DirAccess.open(save_dir)
	if dir == null:
		# Directory doesn't exist, nothing to clean
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Remove save files (.json, .bak, .tmp)
			if file_name.ends_with(".json") or file_name.ends_with(".bak") or file_name.ends_with(".tmp"):
				var err := dir.remove(file_name)
				if err != OK:
					push_warning("U_SaveTestUtils: Failed to remove file: %s (error %d)" % [file_name, err])
		file_name = dir.get_next()
	dir.list_dir_end()

## Remove a specific test directory and all its contents
static func remove_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	# Remove all files first
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Remove the directory itself
	var parent_dir := DirAccess.open("user://")
	if parent_dir:
		var dir_name: String = dir_path.replace("user://", "").trim_suffix("/")
		parent_dir.remove(dir_name)

## Create a test save file with valid structure (for testing load operations)
static func create_test_save(file_path: String, save_data: Dictionary = {}) -> Error:
	# Default valid save structure
	var default_save := {
		"header": {
			"save_version": 1,
			"timestamp": "2025-12-26T10:00:00Z",
			"build_id": "test_build",
			"current_scene_id": "gameplay_base",
			"playtime_seconds": 0,
			"last_checkpoint": "",
			"target_spawn_point": "",
			"area_name": "Test Area",
			"slot_id": "test_slot"
		},
		"state": {
			"gameplay": {"playtime_seconds": 0},
			"scene": {"current_scene_id": "gameplay_base"}
		}
	}

	# Merge with provided data (deep merge for header and state)
	if save_data.has("header"):
		for key in save_data["header"]:
			default_save["header"][key] = save_data["header"][key]
	if save_data.has("state"):
		default_save["state"] = save_data["state"]

	# Write to file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("U_SaveTestUtils: Failed to create test save at: %s" % file_path)
		return FileAccess.get_open_error()

	var json_string := JSON.stringify(default_save, "\t")
	file.store_string(json_string)
	file.close()

	return OK
