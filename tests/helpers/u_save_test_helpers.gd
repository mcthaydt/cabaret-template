class_name U_SaveTestHelpers
extends RefCounted

const _TEST_ROOT_DIR := "user://__tests__"

static var _counter_by_prefix: Dictionary = {}

class SaveFileTracker:
	extends RefCounted

	var _paths: Array[String] = []
	var _make_path: Callable
	var _remove_path: Callable

	func _init(make_path: Callable, remove_path: Callable) -> void:
		_make_path = make_path
		_remove_path = remove_path

	func make_path(prefix: String, extension: String = "json", subdir: String = "save_manager") -> String:
		var path_variant: Variant = _make_path.call(prefix, extension, subdir)
		var path: String = ""
		if path_variant is String:
			path = path_variant as String
		else:
			path = str(path_variant)
		_paths.append(path)
		return path

	func cleanup() -> void:
		for path in _paths:
			_remove_path.call(path)
		_paths.clear()

static func _sanitize_piece(text: String) -> String:
	var cleaned := text.strip_edges()
	cleaned = cleaned.replace(" ", "_")
	cleaned = cleaned.replace("/", "_")
	cleaned = cleaned.replace("\\", "_")
	cleaned = cleaned.replace(":", "_")
	return cleaned

static func ensure_test_subdir(subdir: String) -> String:
	var safe_subdir := _sanitize_piece(subdir)
	var dir_path := "%s/%s" % [_TEST_ROOT_DIR, safe_subdir]
	DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path

static func create_save_file_tracker() -> SaveFileTracker:
	var make_path_callable := func(prefix: String, extension: String, subdir: String) -> String:
		return make_unique_user_file_path(prefix, extension, subdir)

	var remove_path_callable := func(path: String) -> void:
		remove_file_if_exists(path)

	return SaveFileTracker.new(make_path_callable, remove_path_callable)

static func make_unique_user_file_path(prefix: String, extension: String = "json", subdir: String = "save_manager") -> String:
	var safe_subdir := _sanitize_piece(subdir)
	ensure_test_subdir(safe_subdir)

	var safe_prefix := _sanitize_piece(prefix)
	if safe_prefix.is_empty():
		safe_prefix = "test_file"

	var next_index: int = int(_counter_by_prefix.get(safe_prefix, 0)) + 1
	_counter_by_prefix[safe_prefix] = next_index

	var safe_extension := _sanitize_piece(extension)
	if safe_extension.is_empty():
		safe_extension = "json"

	return "%s/%s/%s_%d.%s" % [_TEST_ROOT_DIR, safe_subdir, safe_prefix, next_index, safe_extension]

static func remove_file_if_exists(path: String) -> void:
	if path.is_empty():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func purge_test_subdir(subdir: String) -> void:
	var safe_subdir := _sanitize_piece(subdir)
	var dir_path := "%s/%s" % [_TEST_ROOT_DIR, safe_subdir]

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		dir.remove(file_name)
	dir.list_dir_end()
