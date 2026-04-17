extends BaseTest

## Tests for BaseECSSystem.get_frame_state_snapshot() and _resolve_state_store().
##
## Validates the shared state snapshot extraction pattern: try manager
## snapshot (skip if empty), fall back to state store, return empty dict.

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const I_ECS_MANAGER := preload("res://scripts/interfaces/i_ecs_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

# ─── Stub helpers (distinct names to avoid global class collisions) ─────

class StubStateStore extends I_StateStore:
	var _state: Dictionary = {}

	func dispatch(_action: Dictionary) -> void:
		pass

	func get_state() -> Dictionary:
		return _state

	func is_ready() -> bool:
		return true

	func subscribe(_callback: Callable) -> Callable:
		return Callable()

	func get_slice(_slice_name: StringName) -> Dictionary:
		return {}

class StubECSManager extends I_ECSManager:
	var _frame_snapshot: Dictionary = {}

	func get_frame_state_snapshot() -> Dictionary:
		return _frame_snapshot

	func get_components(_type: StringName) -> Array:
		return []

	func query_entities(_required: Array[StringName], _optional: Array[StringName] = []) -> Array:
		return []

	func register_system(_system: BaseECSSystem) -> void:
		pass

	func mark_systems_dirty() -> void:
		pass

class EmptyManager extends I_ECSManager:
	## Manager without get_frame_state_snapshot — used to test fallback.

	func get_components(_type: StringName) -> Array:
		return []

	func query_entities(_required: Array[StringName], _optional: Array[StringName] = []) -> Array:
		return []

	func register_system(_system: BaseECSSystem) -> void:
		pass

	func mark_systems_dirty() -> void:
		pass

class TestSystem extends BaseECSSystem:
	## Minimal system subclass for testing inherited methods.
	var process_tick_called: bool = false

	func process_tick(_delta: float) -> void:
		process_tick_called = true

class TestSystemWithExport extends BaseECSSystem:
	## System with @export state_store for testing _resolve_state_store override.
	@export var state_store: I_StateStore = null

	func process_tick(_delta: float) -> void:
		pass

	func _resolve_state_store() -> I_StateStore:
		return U_DependencyResolution.resolve_state_store(null, state_store, self)

# ─── Setup / Teardown ───────────────────────────────────────────────────

func before_each() -> void:
	super.before_each()
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	super.after_each()
	U_SERVICE_LOCATOR.clear()

# ─── get_frame_state_snapshot — manager path ────────────────────────────

func test_snapshot_returns_manager_snapshot_when_available() -> void:
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	var manager := StubECSManager.new()
	add_child(manager)
	autofree(manager)
	var expected_state := {"gameplay": {"health": 100}}
	manager._frame_snapshot = expected_state

	system.configure(manager)
	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result, expected_state, "Should return manager's frame state snapshot")

func test_snapshot_falls_through_to_store_when_manager_returns_empty() -> void:
	## When the manager returns an empty snapshot, the base method falls
	## through to the state store — an empty manager snapshot typically means
	## no components are registered yet.
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	var manager := StubECSManager.new()
	add_child(manager)
	autofree(manager)
	manager._frame_snapshot = {}

	var store := StubStateStore.new()
	autofree(store)
	store._state = {"gameplay": {"score": 42}}
	U_SERVICE_LOCATOR.register(&"state_store", store)

	system.configure(manager)
	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result.get("gameplay", {}).get("score", 0), 42, "Should fall through to store when manager returns empty snapshot")

func test_snapshot_falls_back_to_state_store_when_no_manager() -> void:
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	var store := StubStateStore.new()
	autofree(store)
	store._state = {"gameplay": {"score": 50}}
	U_SERVICE_LOCATOR.register(&"state_store", store)

	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result.get("gameplay", {}).get("score", 0), 50, "Should fall back to state store when no manager")

func test_snapshot_returns_empty_dict_when_nothing_available() -> void:
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	# No manager, no store — should return empty dict
	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result.size(), 0, "Should return empty dict when no manager or store available")

func test_snapshot_prefers_manager_over_store() -> void:
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	var manager := StubECSManager.new()
	add_child(manager)
	autofree(manager)
	manager._frame_snapshot = {"source": "manager"}

	var store := StubStateStore.new()
	autofree(store)
	store._state = {"source": "store"}
	U_SERVICE_LOCATOR.register(&"state_store", store)

	system.configure(manager)
	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result.get("source", ""), "manager", "Should prefer manager snapshot over store state")

# ─── _resolve_state_store — default resolution ──────────────────────────

func test_resolve_state_store_default_returns_null_when_no_store() -> void:
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	var result: I_StateStore = system._resolve_state_store()
	assert_null(result, "Default _resolve_state_store should return null when no store registered")

func test_resolve_state_store_default_finds_store_via_service_locator() -> void:
	var system := TestSystem.new()
	add_child(system)
	autofree(system)

	var store := StubStateStore.new()
	autofree(store)
	U_SERVICE_LOCATOR.register(&"state_store", store)

	var result: I_StateStore = system._resolve_state_store()
	assert_same(result, store, "Should find store via ServiceLocator fallback")

func test_resolve_state_store_with_export_uses_export() -> void:
	var system := TestSystemWithExport.new()
	add_child(system)
	autofree(system)

	var store := StubStateStore.new()
	autofree(store)
	system.state_store = store

	var result: I_StateStore = system._resolve_state_store()
	assert_same(result, store, "Should return exported state_store via override")

# ─── get_frame_state_snapshot — integration with _resolve_state_store ───

func test_snapshot_uses_resolve_state_store_when_no_manager() -> void:
	var system := TestSystemWithExport.new()
	add_child(system)
	autofree(system)

	var store := StubStateStore.new()
	autofree(store)
	store._state = {"scene": {"current": "test"}}
	system.state_store = store

	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result.get("scene", {}).get("current", ""), "test", "Should use _resolve_state_store fallback")

func test_snapshot_skips_store_when_manager_has_method() -> void:
	## When manager has get_frame_state_snapshot, store resolution is skipped.
	var system := TestSystemWithExport.new()
	add_child(system)
	autofree(system)

	var manager := StubECSManager.new()
	add_child(manager)
	autofree(manager)
	manager._frame_snapshot = {"source": "manager"}

	var store := StubStateStore.new()
	autofree(store)
	store._state = {"source": "store"}
	system.state_store = store

	system.configure(manager)
	var result: Dictionary = system.get_frame_state_snapshot()
	assert_eq(result.get("source", ""), "manager", "Should use manager snapshot, not store")