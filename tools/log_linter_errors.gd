@tool
extends EditorScript

## Scans all GDScript files and logs linter errors to a file.
## Run this from Godot Editor: File > Run
##
## Output: user://linter_errors.log

const OUTPUT_PATH := "user://linter_errors.log"
const SCRIPT_DIRS := [
	"res://scripts/",
	"res://tests/"
]

# Common shadowed global identifiers we're looking for
const KNOWN_GLOBAL_CLASSES := [
	"C_DamageZoneComponent",
	"U_InputRebindUtils",
	"RS_RebindSettings",
	"RS_InputProfile",
	"U_InputEventSerialization",
	"U_InputEventDisplay",
]

class LintError:
	var file_path: String
	var line_number: int
	var error_type: String
	var message: String

	func _init(path: String, line: int, type: String, msg: String) -> void:
		file_path = path
		line_number = line
		error_type = type
		message = msg

	func to_string() -> String:
		return "%s:%d [%s] %s" % [file_path, line_number, error_type, message]

var _errors: Array[LintError] = []
var _files_scanned: int = 0
var _shadowed_const_count: int = 0

func _run() -> void:
	print("=== Linter Error Scanner ===")
	print("Scanning GDScript files for linting issues...")
	print("")

	_errors.clear()
	_files_scanned = 0
	_shadowed_const_count = 0

	# Scan all script directories
	for dir_path in SCRIPT_DIRS:
		_scan_directory(dir_path)

	# Write results to file
	_write_results_to_file()

	# Print summary
	print("")
	print("=== Summary ===")
	print("Files scanned: %d" % _files_scanned)
	print("Total errors found: %d" % _errors.size())
	print("  - Shadowed const preloads: %d" % _shadowed_const_count)
	print("")
	print("Results written to: %s" % OUTPUT_PATH)
	print("Absolute path: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))

func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Cannot open directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := dir_path.path_join(file_name)

		if dir.current_is_dir():
			# Recursively scan subdirectories
			_scan_directory(full_path)
		elif file_name.ends_with(".gd"):
			# Scan GDScript file
			_scan_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

func _scan_file(file_path: String) -> void:
	_files_scanned += 1

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open file: %s" % file_path)
		return

	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line()

		# Check for shadowed const preloads of known global classes
		_check_shadowed_const_preload(file_path, line_number, line)

	file.close()

func _check_shadowed_const_preload(file_path: String, line_number: int, line: String) -> void:
	# Match pattern: const ClassName := preload("...")
	var regex := RegEx.new()
	regex.compile("^const\\s+(\\w+)\\s*:=\\s*preload\\(")
	var result := regex.search(line)

	if result == null:
		return

	var const_name := result.get_string(1)

	# Check if this const name matches a known global class
	if const_name in KNOWN_GLOBAL_CLASSES:
		var error := LintError.new(
			file_path,
			line_number,
			"SHADOWED_GLOBAL_IDENTIFIER",
			"The constant \"%s\" shadows a global class" % const_name
		)
		_errors.append(error)
		_shadowed_const_count += 1
		return

	# Check if any global class with this name exists
	if ClassDB.class_exists(const_name) or _is_custom_global_class(const_name):
		var error := LintError.new(
			file_path,
			line_number,
			"SHADOWED_GLOBAL_IDENTIFIER",
			"The constant \"%s\" may shadow a global class" % const_name
		)
		_errors.append(error)
		_shadowed_const_count += 1

func _is_custom_global_class(class_name_str: String) -> bool:
	# Check if this is a custom class registered via class_name
	var global_classes := ProjectSettings.get_global_class_list()
	for entry in global_classes:
		if entry.get("class", "") == class_name_str:
			return true
	return false

func _write_results_to_file() -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write to file: %s" % OUTPUT_PATH)
		return

	file.store_line("=== Linter Error Report ===")
	file.store_line("Generated: %s" % Time.get_datetime_string_from_system())
	file.store_line("")
	file.store_line("Files scanned: %d" % _files_scanned)
	file.store_line("Total errors: %d" % _errors.size())
	file.store_line("")

	if _errors.is_empty():
		file.store_line("No errors found! ✓")
	else:
		file.store_line("=== Errors by Type ===")
		file.store_line("")

		# Group errors by type
		var errors_by_type: Dictionary = {}
		for error in _errors:
			if not errors_by_type.has(error.error_type):
				errors_by_type[error.error_type] = []
			errors_by_type[error.error_type].append(error)

		# Write grouped errors
		for error_type in errors_by_type.keys():
			var type_errors: Array = errors_by_type[error_type]
			file.store_line("[%s] (%d errors)" % [error_type, type_errors.size()])
			file.store_line("=" * 60)

			for error in type_errors:
				file.store_line("  %s" % error.to_string())

			file.store_line("")

		file.store_line("")
		file.store_line("=== Quick Fix Commands ===")
		file.store_line("")
		file.store_line("To fix shadowed const preloads, remove the const line:")
		file.store_line("  - These classes are globally available via class_name")
		file.store_line("  - No preload needed, just use the class name directly")

	file.close()
	print("Report written to: %s" % OUTPUT_PATH)
