extends BaseTest

const INVENTORY_PATH := "res://docs/history/cleanup_v8/phase5-scene-inventory.md"
const SCENES_DIR := "res://scenes/"

var _keep_scenes: Array[String] = []
var _keep_scripts: Array[String] = []
var _delete_scenes: Array[String] = []
var _delete_scripts: Array[String] = []

func before_all() -> void:
	_parse_inventory()

func _parse_inventory() -> void:
	if not FileAccess.file_exists(INVENTORY_PATH):
		return
	var content: String = FileAccess.get_file_as_string(INVENTORY_PATH)
	var lines: PackedStringArray = content.split("\n")
	var section: String = ""
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("## Keep"):
			section = "keep"
			continue
		if stripped.begins_with("## Delete"):
			section = "delete"
			continue
		if stripped.begins_with("| `"):
			var parts: PackedStringArray = stripped.split("|")
			if parts.size() < 2:
				continue
			var col: String = parts[1].strip_edges()
			if col.begins_with("`") and col.ends_with("`"):
				col = col.substr(1, col.length() - 2)
			if col.is_empty():
				continue
			if col.ends_with(".tscn") or col.ends_with(".gd"):
				var full_path: String = col
				if col.ends_with(".tscn"):
					full_path = "res://" + col
				if section == "keep":
					if col.ends_with(".tscn"):
						_keep_scenes.append(full_path)
					else:
						_keep_scripts.append(full_path)
				elif section == "delete":
					if col.ends_with(".tscn"):
						_delete_scenes.append(full_path)
					else:
						_delete_scripts.append(full_path)

func _collect_tscn_files_recursive(dir: DirAccess, base_path: String, result: Array[String]) -> void:
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = base_path.path_join(entry)
		if dir.current_is_dir():
			var subdir := DirAccess.open(full_path)
			if subdir != null:
				_collect_tscn_files_recursive(subdir, full_path, result)
		elif entry.ends_with(".tscn"):
			if not result.has(full_path):
				result.append(full_path)
		entry = dir.get_next()

func test_no_scene_classified_delete_still_exists() -> void:
	for scene_path: String in _delete_scenes:
		assert_false(
			FileAccess.file_exists(scene_path),
			"Delete-classified scene should not exist: %s" % scene_path
		)
	for script_path: String in _delete_scripts:
		assert_false(
			FileAccess.file_exists(script_path),
			"Delete-classified script should not exist: %s" % script_path
		)

func test_no_scene_classified_keep_is_missing() -> void:
	for scene_path: String in _keep_scenes:
		assert_true(
			FileAccess.file_exists(scene_path),
			"Keep-classified scene should exist: %s" % scene_path
		)

func test_no_scene_on_disk_is_delete_classified_and_still_exists() -> void:
	var dir := DirAccess.open(SCENES_DIR)
	if dir == null:
		return
	var on_disk: Array[String] = []
	_collect_tscn_files_recursive(dir, SCENES_DIR, on_disk)
	var delete_set: Dictionary = {}
	for f in _delete_scenes:
		delete_set[f] = true
	for scene_path: String in on_disk:
		assert_false(
			delete_set.has(scene_path),
			"Delete-classified scene still exists on disk: %s" % scene_path
		)
