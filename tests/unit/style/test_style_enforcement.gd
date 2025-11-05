extends GutTest

const GD_DIRECTORIES := [
	"res://scripts/gameplay",
	"res://scripts/ecs",
	"res://scripts/state",
	"res://scripts/ui",
	"res://tests/unit/interactables",
	"res://tests/unit/input",
	"res://tests/unit/style",
	"res://tests/unit/ui"
]

const TRIGGER_RESOURCE_DIRECTORIES := [
	"res://resources/triggers"
]

const TRIGGER_RESOURCE_FILES := [
	"res://resources/rs_scene_trigger_settings.tres"
]

func test_gd_files_use_tab_indentation() -> void:
	var offenses: Array[String] = []
	for dir_path in GD_DIRECTORIES:
		_collect_gd_spacing_offenses(dir_path, offenses)
	assert_eq(offenses.size(), 0,
		"All .gd files should use tab indentation. Offending lines:\n%s" % "\n".join(offenses))

func test_trigger_resources_define_script_reference() -> void:
	var missing: Array[String] = []
	for dir_path in TRIGGER_RESOURCE_DIRECTORIES:
		_collect_tres_without_script(dir_path, missing)
	for file_path in TRIGGER_RESOURCE_FILES:
		if not _resource_has_script_reference(file_path):
			missing.append(file_path)
	assert_eq(missing.size(), 0,
		"Trigger settings resources must include script = ExtResource(). Missing:\n%s" % "\n".join(missing))

func _collect_gd_spacing_offenses(dir_path: String, offenses: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_spacing_offenses("%s/%s" % [dir_path, entry], offenses)
		elif entry.ends_with(".gd"):
			_scan_gd_file("%s/%s" % [dir_path, entry], offenses)
		entry = dir.get_next()
	dir.list_dir_end()

func _scan_gd_file(path: String, offenses: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line()
		if line.begins_with(" ") and not line.strip_edges().is_empty():
			offenses.append("%s:%d" % [path, line_number])
	file.close()

func _collect_tres_without_script(dir_path: String, missing: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_tres_without_script("%s/%s" % [dir_path, entry], missing)
		elif entry.ends_with(".tres"):
			var path := "%s/%s" % [dir_path, entry]
			if not _resource_has_script_reference(path):
				missing.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _resource_has_script_reference(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var has_script := false
	while not file.eof_reached():
		if file.get_line().strip_edges().begins_with("script = ExtResource"):
			has_script = true
			break
	file.close()
	return has_script
