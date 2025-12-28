class_name M_SaveFileIO
extends RefCounted

## Helper class for atomic file I/O operations with backup and corruption recovery
##
## Responsibilities:
## - Atomic writes (.tmp -> .json rename pattern)
## - Backup creation (.bak) before overwriting existing saves
## - Corruption recovery (fallback to .bak if .json is invalid)
## - Orphaned .tmp file cleanup

const DEFAULT_SAVE_DIR := "user://saves/"

## Silent mode (suppresses informational warnings - used for tests)
var silent_mode: bool = false

## Ensures the save directory exists, creating it if necessary
func ensure_save_directory(save_dir: String = DEFAULT_SAVE_DIR) -> void:
	var normalized_dir := _normalize_save_dir(save_dir)
	var error: Error = DirAccess.make_dir_recursive_absolute(normalized_dir)
	if error != OK:
		push_error("Failed to create save directory: %s (error %d)" % [normalized_dir, error])

## Saves data to file using atomic write pattern
##
## Process:
## 1. Write to .tmp file
## 2. If original .json exists, copy to .bak
## 3. Rename .tmp to .json
##
## Returns Error code (OK on success)
func save_to_file(file_path: String, data: Dictionary) -> Error:
	var tmp_path: String = file_path + ".tmp"
	var bak_path: String = file_path + ".bak"

	# Step 1: Write to temporary file
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp_file:
		var error: Error = FileAccess.get_open_error()
		push_error("Failed to open temporary file for writing: %s (error %d)" % [tmp_path, error])
		return error

	var json_string: String = JSON.stringify(data, "\t")
	tmp_file.store_string(json_string)
	tmp_file.close()

	# Step 2: If original exists, backup before overwriting
	if FileAccess.file_exists(file_path):
		var error: Error = DirAccess.copy_absolute(file_path, bak_path)
		if error != OK:
			push_warning("Failed to create backup: %s (error %d)" % [bak_path, error])
			# Continue anyway - backup failure shouldn't block save

	# Step 3: Atomic rename (tmp -> json)
	var error: Error = DirAccess.rename_absolute(tmp_path, file_path)
	if error != OK:
		push_error("Failed to rename temporary file: %s -> %s (error %d)" % [tmp_path, file_path, error])
		return error

	return OK

## Loads data from file with automatic fallback to backup on corruption
##
## Returns Dictionary with loaded data, or empty Dictionary on failure
func load_from_file(file_path: String) -> Dictionary:
	# Try to load main file
	if FileAccess.file_exists(file_path):
		var result: Dictionary = _try_load_json(file_path)
		if not result.is_empty():
			return result
		# Main file corrupted, check if backup exists before warning
		var bak_path: String = file_path + ".bak"
		if FileAccess.file_exists(bak_path):
			if not silent_mode:
				push_warning("Main save file corrupted, attempting backup: %s" % file_path)
			var backup_result: Dictionary = _try_load_json(bak_path)
			if not backup_result.is_empty():
				if not silent_mode:
					push_warning("Successfully recovered from backup: %s" % bak_path)
				return backup_result
			else:
				push_error("Backup file also corrupted: %s" % bak_path)
		# No backup exists, return empty
		return {}

	# Main file doesn't exist, check for backup only
	var bak_path: String = file_path + ".bak"
	if FileAccess.file_exists(bak_path):
		var result: Dictionary = _try_load_json(bak_path)
		if not result.is_empty():
			if not silent_mode:
				push_warning("Successfully recovered from backup: %s" % bak_path)
			return result
		else:
			push_error("Backup file also corrupted: %s" % bak_path)

	# Both files missing or corrupted
	return {}

## Cleans up orphaned .tmp files in the specified directory
##
## Called on manager initialization to remove .tmp files from crashed/interrupted saves
func cleanup_tmp_files(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tmp"):
			var tmp_path: String = directory.path_join(file_name)
			var error: Error = dir.remove(file_name)
			if error == OK:
				if not silent_mode:
					push_warning("Cleaned up orphaned temporary file: %s" % tmp_path)
			else:
				push_error("Failed to clean up temporary file: %s (error %d)" % [tmp_path, error])
		file_name = dir.get_next()
	dir.list_dir_end()

## Attempts to load and parse JSON from a file
##
## Returns Dictionary with parsed data, or empty Dictionary on failure
func _try_load_json(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var content: String = file.get_as_text()
	file.close()

	if content.is_empty():
		if not silent_mode:
			push_warning("Save file is empty: %s" % file_path)
		return {}

	var json := JSON.new()
	var parse_error: Error = json.parse(content)
	if parse_error != OK:
		if not silent_mode:
			push_error("JSON parse error in %s at line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return {}

	var data: Variant = json.get_data()
	if not data is Dictionary:
		if not silent_mode:
			push_error("Save file does not contain a valid Dictionary: %s" % file_path)
		return {}

	return data as Dictionary

func _normalize_save_dir(save_dir: String) -> String:
	var normalized := save_dir
	if normalized.is_empty():
		normalized = DEFAULT_SAVE_DIR
	if not normalized.ends_with("/"):
		normalized += "/"
	return normalized
