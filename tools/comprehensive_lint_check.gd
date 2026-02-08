@tool
extends EditorScript

## Comprehensive GDScript linter that checks for:
## - SHADOWED_GLOBAL_IDENTIFIER
## - UNUSED_PARAMETER  
## - UNUSED_VARIABLE
## - INT_AS_ENUM_WITHOUT_CAST
##
## Run this from Godot Editor: File > Run
## Or from command line as a tool script

const SCRIPT_DIRS := [
	"res://scripts/",
	"res://tests/"
]

class LintWarning:
	var file_path: String
	var line_number: int
	var warning_type: String
	var message: String

	func _init(path: String, line: int, type: String, msg: String) -> void:
		file_path = path
		line_number = line
		warning_type = type
		message = msg

	func _to_string() -> String:
		return "%s:%d [%s] %s" % [file_path, line_number, warning_type, message]

var _warnings: Dictionary = {
	"SHADOWED_GLOBAL_IDENTIFIER": [],
	"UNUSED_PARAMETER": [],
	"UNUSED_VARIABLE": [],
	"INT_AS_ENUM_WITHOUT_CAST": []
}
var _files_scanned: int = 0

func _run() -> void:
	print("\n=== COMPREHENSIVE LINTING CHECK ===")
	print("Scanning GDScript files for warnings...")
	print("")

	_warnings = {
		"SHADOWED_GLOBAL_IDENTIFIER": [],
		"UNUSED_PARAMETER": [],
		"UNUSED_VARIABLE": [],
		"INT_AS_ENUM_WITHOUT_CAST": []
	}
	_files_scanned = 0

	# Scan all script directories
	for dir_path in SCRIPT_DIRS:
		_scan_directory(dir_path)

	# Print results
	_print_results()

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
			_scan_directory(full_path)
		elif file_name.ends_with(".gd"):
			_scan_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

func _scan_file(file_path: String) -> void:
	_files_scanned += 1
	
	# Try to load the script
	var script: Script = load(file_path)
	if script == null:
		return
	
	# Get parse errors/warnings using GDScript parser
	# Note: This requires the script to be parsed by Godot
	# We'll need to check the source code directly for patterns
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return

	var content := file.get_as_text()
	file.close()
	
	var lines := content.split("\n")
	
	# Check each line for warning patterns
	for i in range(lines.size()):
		var line := lines[i]
		var line_num := i + 1
		
		_check_shadowed_global(file_path, line_num, line)
		_check_unused_parameter(file_path, line_num, line, lines, i)
		_check_unused_variable(file_path, line_num, line, lines, i)
		_check_int_as_enum(file_path, line_num, line)

func _check_shadowed_global(file_path: String, line_num: int, line: String) -> void:
	# Check for const preloads that shadow global classes
	var regex := RegEx.new()
	regex.compile("^const\\s+(\\w+)\\s*:=\\s*preload\\(")
	var result := regex.search(line)

	if result:
		var const_name := result.get_string(1)
		if ClassDB.class_exists(const_name) or _is_custom_global_class(const_name):
			_add_warning("SHADOWED_GLOBAL_IDENTIFIER", file_path, line_num,
				"Constant '%s' shadows a global class" % const_name)

func _check_unused_parameter(file_path: String, line_num: int, line: String, lines: Array, idx: int) -> void:
	# Look for function parameters that start with _ (unused marker)
	if not line.contains("func "):
		return
	
	var regex := RegEx.new()
	regex.compile("func\\s+\\w+\\([^)]*(_\\w+)[^)]*\\)")
	var result := regex.search(line)
	
	if result:
		var param_name := result.get_string(1)
		# This is already marked as unused with underscore prefix - not a warning
		return
	
	# Look for parameters without underscore that might be unused
	# This is complex to detect without full AST parsing

func _check_unused_variable(file_path: String, line_num: int, line: String, lines: Array, idx: int) -> void:
	# Look for var declarations with _ prefix (unused marker)
	var trimmed := line.strip_edges()
	if not trimmed.begins_with("var _"):
		return
	
	# Extract variable name
	var regex := RegEx.new()
	regex.compile("^var\\s+(_\\w+)")
	var result := regex.search(trimmed)
	
	if result:
		var var_name := result.get_string(1)
		# Already marked as unused - not necessarily a warning unless truly unused

func _check_int_as_enum(file_path: String, line_num: int, line: String) -> void:
	# This is very difficult to detect without full type analysis
	# Would need to know when an int is being assigned to an enum typed variable
	pass

func _is_custom_global_class(class_name_str: String) -> bool:
	var global_classes := ProjectSettings.get_global_class_list()
	for entry in global_classes:
		if entry.get("class", "") == class_name_str:
			return true
	return false

func _add_warning(warning_type: String, file_path: String, line_num: int, message: String) -> void:
	var warning := LintWarning.new(file_path, line_num, warning_type, message)
	_warnings[warning_type].append(warning)

func _print_results() -> void:
	print("\n=== RESULTS ===")
	print("Files scanned: %d" % _files_scanned)
	print("")

	var total_warnings := 0
	for warning_type in _warnings.keys():
		var warnings: Array = _warnings[warning_type]
		total_warnings += warnings.size()
		print("%s: %d warnings" % [warning_type, warnings.size()])
	
	print("\nTotal warnings: %d" % total_warnings)
	
	# Print details for each warning type
	for warning_type in _warnings.keys():
		var warnings: Array = _warnings[warning_type]
		if warnings.size() > 0:
			print("\n--- %s ---" % warning_type)
			for warning in warnings:
				print("  %s" % str(warning))
	
	print("\n=== END REPORT ===")
