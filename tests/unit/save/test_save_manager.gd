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
