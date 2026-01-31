extends BaseTest

const M_SAVE_MANAGER := preload("res://scripts/managers/m_save_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const TEST_SAVE_DIR: String = "user://test_saves/"

var _mock_store: MockStateStore
var _mock_scene_manager: Node
var _save_manager: Node
var _save_test_utils: Script

func before_each() -> void:
	U_ECSEventBus.reset()
	U_ServiceLocator.clear()

	_mock_store = MOCK_STATE_STORE.new()
	add_child(_mock_store)
	autofree(_mock_store)

	_mock_scene_manager = Node.new()
	_mock_scene_manager.name = "MockSceneManager"
	add_child(_mock_scene_manager)
	autofree(_mock_scene_manager)

	U_ServiceLocator.register(StringName("state_store"), _mock_store)
	U_ServiceLocator.register(StringName("scene_manager"), _mock_scene_manager)

	_save_test_utils = load("res://tests/unit/save/u_save_test_utils.gd")
	_save_test_utils.call("setup", TEST_SAVE_DIR)

	await get_tree().process_frame

func after_each() -> void:
	if _save_test_utils != null:
		_save_test_utils.call("teardown", TEST_SAVE_DIR)

func test_delete_slot_removes_thumbnail_file() -> void:
	await _add_save_manager_and_wait()

	var slot_id := StringName("slot_01")
	_create_test_save(slot_id)
	var thumb_path := _get_thumbnail_path(slot_id)
	_create_dummy_thumbnail(thumb_path)

	assert_true(FileAccess.file_exists(thumb_path), "Thumbnail should exist before delete")

	var result: Error = _save_manager.delete_slot(slot_id)
	assert_eq(result, OK, "delete_slot should succeed for existing slot")

	assert_false(FileAccess.file_exists(_get_save_path(slot_id)), "delete_slot should remove save file")
	assert_false(FileAccess.file_exists(thumb_path), "delete_slot should remove thumbnail file")

func test_initialize_cleanup_removes_orphaned_thumbnail() -> void:
	var orphan_slot := StringName("slot_orphan")
	var orphan_path := _get_thumbnail_path(orphan_slot)
	_create_dummy_thumbnail(orphan_path)
	assert_true(FileAccess.file_exists(orphan_path), "Orphaned thumbnail should exist before init")

	await _add_save_manager_and_wait()

	assert_false(FileAccess.file_exists(orphan_path), "Initialization should remove orphaned thumbnails")

func test_cleanup_preserves_thumbnail_with_matching_save() -> void:
	var valid_slot := StringName("slot_02")
	_create_test_save(valid_slot)
	var valid_thumb := _get_thumbnail_path(valid_slot)
	_create_dummy_thumbnail(valid_thumb)

	var orphan_slot := StringName("slot_03")
	var orphan_thumb := _get_thumbnail_path(orphan_slot)
	_create_dummy_thumbnail(orphan_thumb)

	await _add_save_manager_and_wait()

	assert_true(FileAccess.file_exists(valid_thumb), "Cleanup should keep thumbnails with matching save files")
	assert_false(FileAccess.file_exists(orphan_thumb), "Cleanup should remove thumbnails without matching save files")

func test_cleanup_removes_orphaned_thumbnail_without_error() -> void:
	var orphan_slot := StringName("slot_log")
	var orphan_thumb := _get_thumbnail_path(orphan_slot)
	_create_dummy_thumbnail(orphan_thumb)

	await _add_save_manager_and_wait()

	assert_false(FileAccess.file_exists(orphan_thumb), "Cleanup should remove orphaned thumbnails without raising errors")

## Helpers

func _create_save_manager() -> Node:
	var manager := M_SAVE_MANAGER.new()
	manager.set_save_directory(TEST_SAVE_DIR)
	return manager

func _add_save_manager_and_wait() -> void:
	_save_manager = _create_save_manager()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame
	await get_tree().process_frame

func _get_save_path(slot_id: StringName) -> String:
	return TEST_SAVE_DIR + String(slot_id) + ".json"

func _get_thumbnail_path(slot_id: StringName) -> String:
	return TEST_SAVE_DIR + String(slot_id) + "_thumb.png"

func _create_test_save(slot_id: StringName) -> void:
	var save_path := _get_save_path(slot_id)
	if _save_test_utils == null:
		_save_test_utils = load("res://tests/unit/save/u_save_test_utils.gd")
	var result: Error = _save_test_utils.call("create_test_save", save_path, {
		"header": {
			"slot_id": String(slot_id)
		}
	})
	assert_eq(result, OK, "Test save file should be created")

func _create_dummy_thumbnail(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create dummy thumbnail at: %s" % path)
		return
	file.store_string("thumbnail")
	file.close()
