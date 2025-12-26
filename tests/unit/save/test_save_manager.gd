extends BaseTest

const M_SAVE_MANAGER := preload("res://scripts/managers/m_save_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

var _save_manager: Node
var _mock_store: MockStateStore
var _mock_scene_manager: Node

func before_each() -> void:
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

	await get_tree().process_frame

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
