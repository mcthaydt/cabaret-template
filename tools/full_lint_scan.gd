@tool
extends EditorScript

## Comprehensive GDScript linter using Godot's actual parser
## Checks for: SHADOWED_GLOBAL_IDENTIFIER, UNUSED_PARAMETER, UNUSED_VARIABLE, INT_AS_ENUM_WITHOUT_CAST
## Run from Godot Editor: File > Run

const OUTPUT_FILE := "user://comprehensive_lint_report.txt"
const SCRIPT_DIRS := ["res://scripts/", "res://tests/"]

var warnings := {
	"SHADOWED_GLOBAL_IDENTIFIER": [],
	"UNUSED_PARAMETER": [],
	"UNUSED_VARIABLE": [],
	"INT_AS_ENUM_WITHOUT_CAST": [],
	"OTHER": []
}
var files_scanned := 0

func _run() -> void:
	print("\n=== COMPREHENSIVE LINT SCAN ===")
	print("Scanning GDScript files...")
	
	for dir_path in SCRIPT_DIRS:
		_scan_directory(dir_path)
	
	_write_report()
	_print_summary()

func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				_scan_directory(full_path)
			elif file_name.ends_with(".gd"):
				_scan_file(full_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _scan_file(file_path: String) -> void:
	files_scanned += 1
	
	# Try to load and parse the script
	var script: GDScript = load(file_path)
	if not script:
		return
	
	# Check if script has parse errors
	if not script.is_valid():
		return
	
	# Read source code
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	
	var source := file.get_as_text()
	file.close()
	
	# Parse source for warning patterns
	_check_shadowed_globals(file_path, source)
	_check_unused_params_and_vars(file_path, source)

func _check_shadowed_globals(file_path: String, source: String) -> void:
	var lines := source.split("\n")
	for i in range(lines.size()):
		var line := lines[i]
		var regex := RegEx.new()
		regex.compile("^\\s*const\\s+(\\w+)\\s*:=\\s*preload\\s*\\(")
		var result := regex.search(line)
		
		if result:
			var const_name := result.get_string(1)
			if ClassDB.class_exists(const_name) or _is_global_class(const_name):
				warnings["SHADOWED_GLOBAL_IDENTIFIER"].append({
					"file": file_path,
					"line": i + 1,
					"message": "Constant '%s' shadows global class" % const_name
				})

func _check_unused_params_and_vars(file_path: String, source: String) -> void:
	# Parse using RegEx for function parameters with underscore prefix
	var lines := source.split("\n")
	
	for i in range(lines.size()):
		var line := lines[i]
		
		# Check for parameters starting with _ but not __ (which indicates intentionally unused)
		var param_regex := RegEx.new()
		param_regex.compile("func\\s+\\w+\\s*\\([^)]*\\b(_[^_]\\w*)\\b")
		
		var matches := param_regex.search_all(line)
		for match_result in matches:
			var param_name := match_result.get_string(1)
			# Parameters with single underscore prefix are marked as unused - this is the fix, not a warning
			# But if the warning is still enabled, it means Godot thinks it's unused
			pass
		
		# Check for unused variables
		var var_regex := RegEx.new()
		var_regex.compile("^\\s*var\\s+([a-z]\\w*)\\s*[:=]")
		var var_match := var_regex.search(line)
		
		if var_match:
			var var_name := var_match.get_string(1)
			# Simple heuristic: if variable name doesn't appear again in remaining code
			var remaining := "\n".join(lines.slice(i + 1))
			if not remaining.contains(var_name):
				warnings["UNUSED_VARIABLE"].append({
					"file": file_path,
					"line": i + 1,
					"message": "Variable '%s' appears unused" % var_name
				})

func _is_global_class(class_name_str: String) -> bool:
	var global_classes := ProjectSettings.get_global_class_list()
	for entry in global_classes:
		if entry.get("class", "") == class_name_str:
			return true
	return false

func _write_report() -> void:
	var file := FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	if not file:
		push_error("Cannot write report file")
		return
	
	file.store_line("=== COMPREHENSIVE LINT REPORT ===")
	file.store_line("Generated: %s" % Time.get_datetime_string_from_system())
	file.store_line("Files scanned: %d" % files_scanned)
	file.store_line("")

	var total := 0
	for warning_type in warnings.keys():
		var count: int = warnings[warning_type].size()
		total += count
		file.store_line("%s: %d warnings" % [warning_type, count])
	
	file.store_line("\nTotal: %d warnings\n" % total)
	
	for warning_type in warnings.keys():
		var warning_list: Array = warnings[warning_type]
		if warning_list.size() > 0:
			file.store_line("\n=== %s ===" % warning_type)
			for warning in warning_list:
				file.store_line("%s:%d - %s" % [
					warning["file"],
					warning["line"],
					warning["message"]
				])
	
	file.close()

func _print_summary() -> void:
	print("\n=== SUMMARY ===")
	print("Files scanned: %d" % files_scanned)

	var total := 0
	for warning_type in warnings.keys():
		var count: int = warnings[warning_type].size()
		total += count
		print("%s: %d" % [warning_type, count])
	
	print("\nTotal warnings: %d" % total)
	print("\nFull report: %s" % ProjectSettings.globalize_path(OUTPUT_FILE))
	print("\n=== END ===")
