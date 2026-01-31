extends BaseTest

const U_SAVE_TEST_UTILS := preload("res://tests/unit/save/u_save_test_utils.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const TEST_SAVE_DIR := U_SAVE_TEST_UTILS.TEST_SAVE_DIR

class TestSaveManager extends M_SaveManager:
	var autosave_capture_calls: int = 0
	var manual_cache_calls: int = 0
	var autosave_image: Image = null
	var manual_image: Image = null
	var thumbnail_error: Error = OK

	func _capture_autosave_image() -> Image:
		autosave_capture_calls += 1
		return autosave_image

	func _get_cached_manual_image() -> Image:
		manual_cache_calls += 1
		return manual_image

	func _write_thumbnail_image(image: Image, path: String) -> Error:
		if thumbnail_error != OK:
			return thumbnail_error
		return image.save_png(path)

var _mock_store: MockStateStore
var _mock_scene_manager: Node
var _save_manager: TestSaveManager

func before_each() -> void:
	U_ECSEventBus.reset()
	U_ServiceLocator.clear()

	_mock_store = MOCK_STATE_STORE.new()
	_mock_store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	add_child(_mock_store)
	autofree(_mock_store)

	_mock_scene_manager = Node.new()
	_mock_scene_manager.name = "MockSceneManager"
	add_child(_mock_scene_manager)
	autofree(_mock_scene_manager)

	U_ServiceLocator.register(StringName("state_store"), _mock_store)
	U_ServiceLocator.register(StringName("scene_manager"), _mock_scene_manager)

	U_SAVE_TEST_UTILS.setup(TEST_SAVE_DIR)
	_cleanup_thumbnail_files()

	await get_tree().process_frame

func after_each() -> void:
	U_SAVE_TEST_UTILS.teardown(TEST_SAVE_DIR)
	_cleanup_thumbnail_files()

func test_autosave_creates_thumbnail_and_metadata_path() -> void:
	_save_manager = _create_save_manager()
	_save_manager.autosave_image = Image.create(64, 36, false, Image.FORMAT_RGBA8)
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame
	_seed_state_for_save()

	var result: Error = _save_manager.save_to_slot(StringName("autosave"))
	assert_eq(result, OK, "Autosave should still succeed when thumbnail capture succeeds")
	assert_eq(_save_manager.autosave_capture_calls, 1, "Autosave should capture a live screenshot")
	assert_eq(_save_manager.manual_cache_calls, 0, "Autosave should not use cached screenshots")

	var thumb_path := _get_thumbnail_path(StringName("autosave"))
	assert_true(FileAccess.file_exists(thumb_path), "Autosave should write thumbnail PNG")

	var header: Dictionary = _load_header(StringName("autosave"))
	assert_eq(header.get("thumbnail_path", ""), thumb_path, "Metadata should store thumbnail path when capture succeeds")

func test_manual_save_uses_cached_screenshot() -> void:
	_save_manager = _create_save_manager()
	_save_manager.manual_image = Image.create(64, 36, false, Image.FORMAT_RGBA8)
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame
	_seed_state_for_save()

	var result: Error = _save_manager.save_to_slot(StringName("slot_01"))
	assert_eq(result, OK, "Manual save should succeed when cached image exists")
	assert_eq(_save_manager.autosave_capture_calls, 0, "Manual save should not capture a live screenshot")
	assert_eq(_save_manager.manual_cache_calls, 1, "Manual save should read from cached screenshot")

	var thumb_path := _get_thumbnail_path(StringName("slot_01"))
	assert_true(FileAccess.file_exists(thumb_path), "Manual save should write thumbnail PNG from cache")

	var header: Dictionary = _load_header(StringName("slot_01"))
	assert_eq(header.get("thumbnail_path", ""), thumb_path, "Metadata should store thumbnail path for manual save")

func test_manual_save_without_cache_skips_thumbnail() -> void:
	_save_manager = _create_save_manager()
	_save_manager.manual_image = null
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame
	_seed_state_for_save()

	var result: Error = _save_manager.save_to_slot(StringName("slot_02"))
	assert_eq(result, OK, "Manual save should succeed even without cached image")

	var thumb_path := _get_thumbnail_path(StringName("slot_02"))
	assert_false(FileAccess.file_exists(thumb_path), "Manual save without cache should not write thumbnail")

	var header: Dictionary = _load_header(StringName("slot_02"))
	assert_eq(header.get("thumbnail_path", ""), "", "Metadata should keep thumbnail_path empty when capture fails")

func test_thumbnail_failure_does_not_block_save() -> void:
	_save_manager = _create_save_manager()
	_save_manager.autosave_image = Image.create(64, 36, false, Image.FORMAT_RGBA8)
	_save_manager.thumbnail_error = ERR_CANT_CREATE
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame
	_seed_state_for_save()

	var result: Error = _save_manager.save_to_slot(StringName("autosave"))
	assert_eq(result, OK, "Save should succeed even if thumbnail write fails")

	var thumb_path := _get_thumbnail_path(StringName("autosave"))
	assert_false(FileAccess.file_exists(thumb_path), "Thumbnail file should not exist when write fails")

	var header: Dictionary = _load_header(StringName("autosave"))
	assert_eq(header.get("thumbnail_path", ""), "", "Metadata should keep thumbnail_path empty when write fails")

## Helpers

func _create_save_manager() -> TestSaveManager:
	var manager := TestSaveManager.new()
	manager.set_save_directory(TEST_SAVE_DIR)
	return manager

func _seed_state_for_save() -> void:
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 0,
		"last_checkpoint": "",
		"target_spawn_point": ""
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "gameplay_base"
	})

func _get_thumbnail_path(slot_id: StringName) -> String:
	return TEST_SAVE_DIR + String(slot_id) + "_thumb.png"

func _load_header(slot_id: StringName) -> Dictionary:
	var file_path := TEST_SAVE_DIR + String(slot_id) + ".json"
	var content: String = FileAccess.get_file_as_string(file_path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}
	var header: Variant = parsed.get("header", {})
	if header is Dictionary:
		return header
	return {}

func _cleanup_thumbnail_files() -> void:
	var dir := DirAccess.open(TEST_SAVE_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with("_thumb.png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
