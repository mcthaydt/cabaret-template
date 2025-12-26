extends BaseTest

const M_SAVE_MANAGER := preload("res://scripts/managers/m_save_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

var _save_manager: Node
var _mock_store: MockStateStore
var _mock_scene_manager: Node

func before_each() -> void:
	# Reset ECS event bus to prevent subscription leaks
	U_ECSEventBus.reset()

	# Clear ServiceLocator to prevent warnings
	U_ServiceLocator.clear()

	# Create mock state store
	_mock_store = MOCK_STATE_STORE.new()
	add_child(_mock_store)
	autofree(_mock_store)

	# Create mock scene manager
	_mock_scene_manager = Node.new()
	_mock_scene_manager.name = "MockSceneManager"
	add_child(_mock_scene_manager)
	autofree(_mock_scene_manager)

	# Register mocks with ServiceLocator
	U_ServiceLocator.register(StringName("state_store"), _mock_store)
	U_ServiceLocator.register(StringName("scene_manager"), _mock_scene_manager)

	# Ensure test directory exists and is clean
	_ensure_test_directory_clean()

	await get_tree().process_frame

func after_each() -> void:
	# Clean up test files
	_cleanup_test_files()

## Test helpers

func _ensure_test_directory_clean() -> void:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		DirAccess.make_dir_recursive_absolute("user://saves/")

func _cleanup_test_files() -> void:
	# Remove all test save files
	var dir := DirAccess.open("user://saves/")
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".json") or file_name.ends_with(".bak") or file_name.ends_with(".tmp")):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Phase 1: Manager Lifecycle and Discovery Tests

func test_manager_extends_node() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	assert_true(_save_manager is Node, "Save manager should extend Node")
	autofree(_save_manager)

func test_manager_adds_to_save_manager_group() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var nodes_in_group: Array = get_tree().get_nodes_in_group("save_manager")
	assert_true(nodes_in_group.has(_save_manager), "Manager should add itself to 'save_manager' group")

func test_manager_registers_with_service_locator() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var service: Node = U_ServiceLocator.get_service(StringName("save_manager"))
	assert_not_null(service, "Manager should register with ServiceLocator")
	assert_eq(service, _save_manager, "ServiceLocator should return the correct manager instance")

func test_manager_discovers_state_store_dependency() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Manager should have discovered and stored reference to state store
	assert_true(_save_manager.has_method("_get_state_store"), "Manager should have _get_state_store method")
	var store: Variant = _save_manager.call("_get_state_store")
	assert_not_null(store, "Manager should discover state store")
	assert_eq(store, _mock_store, "Manager should reference the correct state store")

func test_manager_discovers_scene_manager_dependency() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Manager should have discovered and stored reference to scene manager
	assert_true(_save_manager.has_method("_get_scene_manager"), "Manager should have _get_scene_manager method")
	var manager: Variant = _save_manager.call("_get_scene_manager")
	assert_not_null(manager, "Manager should discover scene manager")
	assert_eq(manager, _mock_scene_manager, "Manager should reference the correct scene manager")

func test_manager_initializes_lock_flags() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Manager should initialize lock flags to false
	assert_true(_save_manager.has_method("_is_saving_locked"), "Manager should have _is_saving_locked method")
	assert_true(_save_manager.has_method("_is_loading_locked"), "Manager should have _is_loading_locked method")

	var is_saving: bool = _save_manager.call("_is_saving_locked")
	var is_loading: bool = _save_manager.call("_is_loading_locked")

	assert_false(is_saving, "Manager should initialize with _is_saving = false")
	assert_false(is_loading, "Manager should initialize with _is_loading = false")

## Phase 2: Slot Registry and Metadata Tests

func test_get_all_slot_ids_returns_correct_slots() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var slot_ids: Array = _save_manager.get_all_slot_ids()
	assert_eq(slot_ids.size(), 4, "Should have 4 slots total")
	assert_has(slot_ids, StringName("autosave"), "Should include autosave slot")
	assert_has(slot_ids, StringName("slot_01"), "Should include slot_01")
	assert_has(slot_ids, StringName("slot_02"), "Should include slot_02")
	assert_has(slot_ids, StringName("slot_03"), "Should include slot_03")

func test_slot_exists_returns_false_for_nonexistent_slot() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var exists: bool = _save_manager.slot_exists(StringName("slot_01"))
	assert_false(exists, "Nonexistent slot should return false")

func test_get_slot_metadata_returns_empty_for_nonexistent_slot() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var metadata: Dictionary = _save_manager.get_slot_metadata(StringName("slot_01"))
	assert_true(metadata.is_empty(), "Nonexistent slot should return empty metadata")

func test_get_all_slot_metadata_returns_array_with_correct_size() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var all_metadata: Array[Dictionary] = _save_manager.get_all_slot_metadata()
	assert_eq(all_metadata.size(), 4, "Should return metadata for all 4 slots")

func test_build_metadata_includes_required_fields() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state with required fields
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 3661,  # 1 hour, 1 minute, 1 second
		"last_checkpoint": "cp_test",
		"target_spawn_point": "sp_test"
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "gameplay_base"
	})

	# Call internal metadata builder
	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	# Assert required fields present
	assert_true(metadata.has("save_version"), "Metadata should have save_version")
	assert_true(metadata.has("timestamp"), "Metadata should have timestamp")
	assert_true(metadata.has("build_id"), "Metadata should have build_id")
	assert_true(metadata.has("playtime_seconds"), "Metadata should have playtime_seconds")
	assert_true(metadata.has("current_scene_id"), "Metadata should have current_scene_id")
	assert_true(metadata.has("last_checkpoint"), "Metadata should have last_checkpoint")
	assert_true(metadata.has("target_spawn_point"), "Metadata should have target_spawn_point")
	assert_true(metadata.has("area_name"), "Metadata should have area_name")
	assert_true(metadata.has("slot_id"), "Metadata should have slot_id")

func test_build_metadata_derives_area_name_from_scene_registry() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 0,
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "gameplay_base"
	})

	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	# Should derive area_name from scene registry
	assert_not_null(metadata.get("area_name", null), "Should derive area_name from scene_id")
	# gameplay_base should format to "Gameplay Base" or use display_name from registry
	assert_true(metadata["area_name"] is String, "area_name should be a string")
	assert_gt(metadata["area_name"].length(), 0, "area_name should not be empty")

func test_build_metadata_formats_timestamp_as_iso8601() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 0})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	# Timestamp should be ISO 8601 format (contains 'T' separator and 'Z' suffix)
	var timestamp: String = metadata.get("timestamp", "")
	assert_true(timestamp.contains("T"), "Timestamp should be ISO 8601 format with 'T' separator")
	assert_true(timestamp.ends_with("Z"), "Timestamp should end with 'Z' for UTC")

func test_build_metadata_uses_save_version_1() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 0})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	assert_eq(metadata.get("save_version", -1), 1, "Current save_version should be 1")

## Phase 2: Edge Case Tests

func test_build_metadata_handles_missing_scene_slice() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Only set gameplay slice, no scene slice
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 0})

	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	# Should handle missing scene slice gracefully
	assert_eq(metadata.get("current_scene_id", null), "", "Missing scene slice should result in empty scene_id")
	assert_eq(metadata.get("area_name", null), "Unknown", "Missing scene_id should result in 'Unknown' area name")

func test_build_metadata_fallback_area_name_formatting() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Use a scene_id that's NOT in the registry
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 0})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "custom_test_area"
	})

	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	# Should format scene_id into readable name
	assert_eq(metadata.get("area_name", null), "Custom Test Area", "Should format unknown scene_id into readable name")

func test_build_metadata_handles_missing_gameplay_fields() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Set empty gameplay slice
	_mock_store.set_slice(StringName("gameplay"), {})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	var metadata: Dictionary = _save_manager.call("_build_metadata", StringName("slot_01"))

	# Should use defaults for missing fields
	assert_eq(metadata.get("playtime_seconds", -1), 0, "Missing playtime should default to 0")
	assert_eq(metadata.get("last_checkpoint", null), "", "Missing checkpoint should default to empty string")
	assert_eq(metadata.get("target_spawn_point", null), "", "Missing spawn point should default to empty string")

func test_get_all_slot_metadata_with_nonexistent_slots() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	var all_metadata: Array[Dictionary] = _save_manager.get_all_slot_metadata()

	# All slots should be marked as nonexistent
	for metadata in all_metadata:
		assert_false(metadata.get("exists", true), "All slots should be marked as nonexistent when no saves exist")
		assert_true(metadata.has("slot_id"), "All entries should have slot_id")
		assert_true(metadata.get("slot_id") in M_SAVE_MANAGER.ALL_SLOTS, "slot_id should be a valid slot")

## Phase 3+: Persistable State Tests

func test_state_store_has_get_persistable_state_method() -> void:
	# Verify M_StateStore exposes get_persistable_state() for Save Manager
	assert_true(_mock_store.has_method("get_persistable_state"), "M_StateStore should have get_persistable_state() method")

func test_state_store_has_get_slice_configs_method() -> void:
	# Verify M_StateStore exposes get_slice_configs() for advanced use cases
	assert_true(_mock_store.has_method("get_slice_configs"), "M_StateStore should have get_slice_configs() method")

## Phase 4: Manual Save Workflow Tests

func test_save_to_slot_returns_ok_when_successful() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	# Should return OK on successful save
	var result: Error = _save_manager.save_to_slot(StringName("slot_01"))
	assert_eq(result, OK, "save_to_slot should return OK on success")

func test_save_to_slot_rejects_when_already_saving() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	# Manually set _is_saving to true (simulate concurrent save)
	_save_manager.set("_is_saving", true)

	# Should reject with ERR_BUSY
	var result: Error = _save_manager.save_to_slot(StringName("slot_01"))
	assert_eq(result, ERR_BUSY, "save_to_slot should return ERR_BUSY when already saving")

func test_save_to_slot_emits_save_started_event() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	# Subscribe to save_started event (use Array to capture mutable state)
	var event_data: Array = [false, null]  # [received, event]
	U_ECSEventBus.subscribe(StringName("save_started"), func(event: Variant) -> void:
		event_data[0] = true
		event_data[1] = event
	)

	# Perform save
	_save_manager.save_to_slot(StringName("slot_01"))

	# Verify event was published
	assert_true(event_data[0], "save_started event should be published")
	assert_true(event_data[1] is Dictionary, "Event should be a Dictionary")

	# Extract payload from event wrapper
	var event: Dictionary = event_data[1] as Dictionary
	var payload: Dictionary = event.get("payload", {}) as Dictionary

	assert_eq(payload.get("slot_id"), StringName("slot_01"), "Event payload should include slot_id")
	assert_false(payload.get("is_autosave", true), "Manual save should have is_autosave=false")

func test_save_to_slot_emits_save_completed_event() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	# Subscribe to save_completed event (use Array to capture mutable state)
	var event_data: Array = [false, null]  # [received, event]
	U_ECSEventBus.subscribe(StringName("save_completed"), func(event: Variant) -> void:
		event_data[0] = true
		event_data[1] = event
	)

	# Perform save
	_save_manager.save_to_slot(StringName("slot_01"))

	# Verify event was published
	assert_true(event_data[0], "save_completed event should be published on success")
	assert_true(event_data[1] is Dictionary, "Event should be a Dictionary")

	# Extract payload from event wrapper
	var event: Dictionary = event_data[1] as Dictionary
	var payload: Dictionary = event.get("payload", {}) as Dictionary

	assert_eq(payload.get("slot_id"), StringName("slot_01"), "Event payload should include slot_id")

func test_save_to_slot_sets_and_clears_is_saving_lock() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	# Verify initial state
	assert_false(_save_manager.call("_is_saving_locked"), "_is_saving should be false initially")

	# Perform save
	_save_manager.save_to_slot(StringName("slot_01"))

	# After save completes, lock should be cleared
	assert_false(_save_manager.call("_is_saving_locked"), "_is_saving should be false after save completes")

func test_save_to_slot_writes_file_with_header_and_state() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state with recognizable data
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 3600,
		"player_health": 75.0,
		"last_checkpoint": "cp_test"
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "gameplay_base"
	})

	# Perform save
	var result: Error = _save_manager.save_to_slot(StringName("slot_01"))
	assert_eq(result, OK, "Save should succeed")

	# Verify file was written
	var file_path: String = _save_manager.call("_get_slot_file_path", StringName("slot_01"))
	assert_true(FileAccess.file_exists(file_path), "Save file should exist after save")

	# Load and verify contents
	var file_io := M_SaveFileIO.new()
	file_io.silent_mode = true
	var loaded_data: Dictionary = file_io.load_from_file(file_path)

	# Verify structure: {header, state}
	assert_true(loaded_data.has("header"), "Save file should have header")
	assert_true(loaded_data.has("state"), "Save file should have state")

	# Verify header fields
	var header: Dictionary = loaded_data["header"]
	assert_eq(header.get("save_version"), 1, "Header should have save_version=1")
	assert_eq(header.get("slot_id"), StringName("slot_01"), "Header should have correct slot_id")
	assert_eq(header.get("playtime_seconds"), 3600, "Header should have playtime from state")
	assert_eq(header.get("current_scene_id"), "gameplay_base", "Header should have scene_id from state")

	# Verify state was included
	var state: Dictionary = loaded_data["state"]
	assert_true(state.has("gameplay"), "State should include gameplay slice")
	assert_eq(state["gameplay"].get("player_health"), 75.0, "State should preserve gameplay data")

func test_save_to_slot_calls_get_persistable_state() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup mock state with both persistable and transient fields
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 100,  # persistable
		"player_health": 75.0      # persistable
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "gameplay_base",  # persistable
		"is_transitioning": true               # transient (if defined in slice config)
	})

	# Perform save
	var result: Error = _save_manager.save_to_slot(StringName("slot_01"))
	assert_eq(result, OK, "Save should succeed")

	# Load the saved file and verify structure
	var file_path: String = _save_manager.call("_get_slot_file_path", StringName("slot_01"))
	var file_io := M_SaveFileIO.new()
	file_io.silent_mode = true
	var loaded_data: Dictionary = file_io.load_from_file(file_path)

	# Verify the file was saved with correct structure
	assert_true(loaded_data.has("header"), "Save file should have header")
	assert_true(loaded_data.has("state"), "Save file should have state")

	# Verify state was filtered (get_persistable_state was called)
	var state: Dictionary = loaded_data["state"]
	assert_true(state.has("gameplay"), "State should include gameplay slice")
	assert_true(state.has("scene"), "State should include scene slice")

	# Verify persistable fields are present
	assert_eq(state["gameplay"].get("playtime_seconds"), 100, "Persistable field should be saved")
	assert_eq(state["gameplay"].get("player_health"), 75.0, "Persistable field should be saved")

func test_request_autosave_saves_to_autosave_slot() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup state
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 42})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})

	# Request autosave
	_save_manager.request_autosave()

	await get_tree().process_frame

	# Verify autosave file was created
	var autosave_path: String = "user://saves/autosave.json"
	assert_true(FileAccess.file_exists(autosave_path), "Autosave file should exist")

	# Verify it's the autosave slot
	var file := FileAccess.open(autosave_path, FileAccess.READ)
	var json_string: String = file.get_as_text()
	file.close()
	var loaded_data: Dictionary = JSON.parse_string(json_string)
	assert_eq(loaded_data["header"]["slot_id"], "autosave", "Should save to autosave slot")

## Phase 4+: Delete and Metadata Reading Tests

func test_delete_slot_removes_save_files() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup and save to create files
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Verify files exist
	var file_path: String = _save_manager.call("_get_slot_file_path", StringName("slot_01"))
	assert_true(FileAccess.file_exists(file_path), "Save file should exist before delete")

	# Delete the slot
	var result: Error = _save_manager.delete_slot(StringName("slot_01"))
	assert_eq(result, OK, "delete_slot should return OK on success")

	# Verify files are removed
	assert_false(FileAccess.file_exists(file_path), "Save file should be deleted")
	assert_false(FileAccess.file_exists(file_path + ".bak"), "Backup file should be deleted")

func test_delete_slot_rejects_autosave_slot() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Try to delete autosave slot
	var result: Error = _save_manager.delete_slot(StringName("autosave"))
	assert_eq(result, ERR_UNAUTHORIZED, "delete_slot should reject autosave slot with ERR_UNAUTHORIZED")

func test_delete_slot_returns_error_for_nonexistent_slot() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Try to delete nonexistent slot
	var result: Error = _save_manager.delete_slot(StringName("slot_01"))
	assert_eq(result, ERR_FILE_NOT_FOUND, "delete_slot should return ERR_FILE_NOT_FOUND for nonexistent slot")

func test_get_slot_metadata_reads_from_existing_file() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Setup and save
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 7200,  # 2 hours
		"last_checkpoint": "cp_final",
		"target_spawn_point": "sp_boss"
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "interior_house"
	})
	_save_manager.save_to_slot(StringName("slot_02"))

	# Read metadata back
	var metadata: Dictionary = _save_manager.get_slot_metadata(StringName("slot_02"))

	# Verify metadata fields
	assert_false(metadata.is_empty(), "Metadata should not be empty for existing slot")
	assert_eq(metadata.get("slot_id"), StringName("slot_02"), "Metadata should include slot_id")
	assert_eq(metadata.get("playtime_seconds"), 7200, "Metadata should include playtime")
	assert_eq(metadata.get("current_scene_id"), "interior_house", "Metadata should include scene_id")
	assert_eq(metadata.get("last_checkpoint"), "cp_final", "Metadata should include checkpoint")
	assert_eq(metadata.get("target_spawn_point"), "sp_boss", "Metadata should include spawn point")
	assert_true(metadata.has("timestamp"), "Metadata should include timestamp")
	assert_true(metadata.has("area_name"), "Metadata should include area_name")

func test_get_all_slot_metadata_includes_existing_slots_with_data() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Save to slot_01
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Get all metadata
	var all_metadata: Array[Dictionary] = _save_manager.get_all_slot_metadata()
	assert_eq(all_metadata.size(), 4, "Should return metadata for all 4 slots")

	# Find slot_01 in the list
	var slot_01_meta: Dictionary = {}
	for meta in all_metadata:
		if meta.get("slot_id") == StringName("slot_01"):
			slot_01_meta = meta
			break

	# Verify slot_01 has full metadata
	assert_true(slot_01_meta.get("exists", false), "slot_01 should be marked as exists=true")
	assert_eq(slot_01_meta.get("playtime_seconds"), 100, "slot_01 should have playtime data")

## Phase 5: Load Workflow Tests

func test_load_from_slot_rejects_when_already_loading() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Manually set _is_loading to true (simulate concurrent load)
	_save_manager.set("_is_loading", true)

	# Should reject with ERR_BUSY
	var result: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(result, ERR_BUSY, "load_from_slot should return ERR_BUSY when already loading")

func test_load_from_slot_rejects_during_scene_transition() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Add is_transitioning method to mock scene manager
	_mock_scene_manager.set_script(load("res://tests/mocks/mock_scene_manager_with_transition.gd"))
	_mock_scene_manager.set("_is_transitioning", true)

	# Should reject with ERR_BUSY
	var result: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(result, ERR_BUSY, "load_from_slot should return ERR_BUSY during scene transition")

func test_load_from_slot_rejects_nonexistent_slot() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Try to load from empty slot
	var result: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(result, ERR_FILE_NOT_FOUND, "load_from_slot should return ERR_FILE_NOT_FOUND for nonexistent slot")

func test_load_from_slot_sets_and_clears_is_loading_lock() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Create a valid save first
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "gameplay_base"})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Add transition method to mock scene manager
	_mock_scene_manager.set_script(load("res://tests/mocks/mock_scene_manager_with_transition.gd"))
	_mock_scene_manager.set("_is_transitioning", false)

	# Verify initial state
	assert_false(_save_manager.call("_is_loading_locked"), "_is_loading should be false initially")

	# Perform load (this will trigger scene transition)
	_save_manager.load_from_slot(StringName("slot_01"))

	# Lock should STAY SET during transition (new behavior!)
	assert_true(_save_manager.call("_is_loading_locked"), "_is_loading should stay true during transition")

	# Simulate transition completion by dispatching the action
	const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
	_mock_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))

	# Now lock should be cleared
	assert_false(_save_manager.call("_is_loading_locked"), "_is_loading should be false after transition completes")

func test_load_from_slot_lock_stays_set_during_transition() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Create a valid save
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "exterior"})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Setup mock scene manager
	_mock_scene_manager.set_script(load("res://tests/mocks/mock_scene_manager_with_transition.gd"))
	_mock_scene_manager.set("_is_transitioning", false)

	# Perform load
	var result: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(result, OK, "Load should succeed")

	# Lock should stay set until transition completes
	assert_true(_save_manager.call("_is_loading_locked"), "Lock should stay set during transition")

	# Attempting another load should fail with ERR_BUSY
	var second_load: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(second_load, ERR_BUSY, "Second load should be rejected while first is in progress")

func test_load_from_slot_lock_clears_only_for_matching_scene() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Create a save for "exterior" scene
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "exterior"})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Setup mock scene manager
	_mock_scene_manager.set_script(load("res://tests/mocks/mock_scene_manager_with_transition.gd"))
	_mock_scene_manager.set("_is_transitioning", false)

	# Perform load
	_save_manager.load_from_slot(StringName("slot_01"))

	# Lock should be set
	assert_true(_save_manager.call("_is_loading_locked"), "Lock should be set")

	# Dispatch transition_completed for WRONG scene
	const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
	_mock_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("interior_house")))

	# Lock should STILL be set (wrong scene)
	assert_true(_save_manager.call("_is_loading_locked"), "Lock should stay set when wrong scene completes")

	# Dispatch transition_completed for CORRECT scene
	_mock_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))

	# Now lock should be cleared
	assert_false(_save_manager.call("_is_loading_locked"), "Lock should clear when correct scene completes")

func test_load_from_slot_preserves_state_to_handoff() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Create a save with specific data
	_mock_store.set_slice(StringName("gameplay"), {
		"playtime_seconds": 500,
		"player_health": 50.0,
		"last_checkpoint": "cp_saved"
	})
	_mock_store.set_slice(StringName("scene"), {
		"current_scene_id": "interior_house"
	})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Add transition method to mock scene manager
	_mock_scene_manager.set_script(load("res://tests/mocks/mock_scene_manager_with_transition.gd"))
	_mock_scene_manager.set("_is_transitioning", false)

	# Clear handoff to ensure clean state
	U_STATE_HANDOFF.clear_all()

	# Load the save
	var result: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(result, OK, "Load should succeed")

	# Verify state was preserved to handoff
	var restored_gameplay: Dictionary = U_STATE_HANDOFF.restore_slice(StringName("gameplay"))
	assert_false(restored_gameplay.is_empty(), "Gameplay state should be preserved to handoff")
	assert_eq(restored_gameplay.get("playtime_seconds"), 500, "Preserved state should match saved data")
	assert_eq(restored_gameplay.get("player_health"), 50.0, "Preserved state should include health")

func test_load_from_slot_triggers_scene_transition() -> void:
	_save_manager = M_SAVE_MANAGER.new()
	add_child(_save_manager)
	autofree(_save_manager)

	await get_tree().process_frame

	# Create a save with a specific scene
	_mock_store.set_slice(StringName("gameplay"), {"playtime_seconds": 100})
	_mock_store.set_slice(StringName("scene"), {"current_scene_id": "exterior"})
	_save_manager.save_to_slot(StringName("slot_01"))

	# Add transition method to mock scene manager and track calls
	_mock_scene_manager.set_script(load("res://tests/mocks/mock_scene_manager_with_transition.gd"))
	_mock_scene_manager.set("_is_transitioning", false)
	_mock_scene_manager.set("_transition_called", false)
	_mock_scene_manager.set("_transition_target", StringName(""))

	# Load the save
	var result: Error = _save_manager.load_from_slot(StringName("slot_01"))
	assert_eq(result, OK, "Load should succeed")

	# Verify scene transition was requested
	assert_true(_mock_scene_manager.get("_transition_called"), "Scene transition should be called")
	assert_eq(_mock_scene_manager.get("_transition_target"), StringName("exterior"), "Should transition to saved scene_id")
