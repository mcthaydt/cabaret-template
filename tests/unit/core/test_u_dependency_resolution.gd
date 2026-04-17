extends BaseTest

## Tests for U_DependencyResolution — shared dependency resolution utility.
##
## TDD RED phase: these tests define the expected behavior before the
## implementation exists. They should FAIL until U_DependencyResolution is
## implemented in Commit 2 (GREEN).

const DEP_RES_PATH := "res://scripts/utils/core/u_dependency_resolution.gd"
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")

var _dep_res: Variant = null

# ─── Stub helpers (distinct names to avoid global class collisions) ─────

class StubService extends Node:
	var service_name: String = "stub_service"

class StubStateStore extends I_StateStore:
	var _ready_flag: bool = false
	var _state: Dictionary = {}

	func dispatch(_action: Dictionary) -> void:
		pass

	func get_state() -> Dictionary:
		return _state

	func is_ready() -> bool:
		return _ready_flag

	func subscribe(_callback: Callable) -> Callable:
		return Callable()

	func get_slice(_slice_name: StringName) -> Dictionary:
		return {}

class StubOwner extends Node:
	@export var state_store: I_StateStore = null

# ─── Setup / Teardown ───────────────────────────────────────────────────

func before_each() -> void:
	super.before_each()
	U_SERVICE_LOCATOR.clear()
	var script_obj: Script = load(DEP_RES_PATH) as Script
	if script_obj != null:
		_dep_res = script_obj.new()

func after_each() -> void:
	super.after_each()
	U_SERVICE_LOCATOR.clear()

# ─── resolve() — cached value ───────────────────────────────────────────

func test_resolve_returns_cached_value_when_valid() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var cached := StubService.new()
	autofree(cached)
	var result: Variant = _dep_res.resolve(&"test_service", cached, null)
	assert_same(result, cached, "Should return cached value when valid")

func test_resolve_returns_cached_value_even_if_export_available() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var cached := StubService.new()
	autofree(cached)
	var exported := StubService.new()
	autofree(exported)
	var result: Variant = _dep_res.resolve(&"test_service", cached, exported)
	assert_same(result, cached, "Cached value should take priority over export")

func test_resolve_returns_cached_value_even_if_service_registered() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var cached := StubService.new()
	autofree(cached)
	var registered := StubService.new()
	autofree(registered)
	U_SERVICE_LOCATOR.register(&"test_service", registered)
	var result: Variant = _dep_res.resolve(&"test_service", cached, null)
	assert_same(result, cached, "Cached value should take priority over ServiceLocator")

# ─── resolve() — export fallback ─────────────────────────────────────────

func test_resolve_returns_export_when_cache_null() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var exported := StubService.new()
	autofree(exported)
	var result: Variant = _dep_res.resolve(&"test_service", null, exported)
	assert_same(result, exported, "Should return export value when cache is null")

func test_resolve_returns_export_when_cache_freed() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var exported := StubService.new()
	autofree(exported)
	var freed_cache := StubService.new()
	freed_cache.free()
	var result: Variant = _dep_res.resolve(&"test_service", freed_cache, exported)
	assert_same(result, exported, "Should skip freed cache and return export")

# ─── resolve() — ServiceLocator fallback ─────────────────────────────────

func test_resolve_falls_back_to_service_locator() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var service := StubService.new()
	autofree(service)
	U_SERVICE_LOCATOR.register(&"test_service", service)
	var result: Variant = _dep_res.resolve(&"test_service", null, null)
	assert_same(result, service, "Should fall back to ServiceLocator when cache and export are null")

func test_resolve_falls_back_to_service_locator_when_cache_and_export_freed() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var service := StubService.new()
	autofree(service)
	U_SERVICE_LOCATOR.register(&"test_service", service)
	var freed_cache := StubService.new()
	freed_cache.free()
	var freed_export := StubService.new()
	freed_export.free()
	var result: Variant = _dep_res.resolve(&"test_service", freed_cache, freed_export)
	assert_same(result, service, "Should fall back to ServiceLocator when cache and export are freed")

# ─── resolve() — null when unavailable ──────────────────────────────────

func test_resolve_returns_null_when_all_unavailable() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var result: Variant = _dep_res.resolve(&"nonexistent_service", null, null)
	assert_null(result, "Should return null when no resolution path succeeds")

func test_resolve_returns_null_when_service_not_registered() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var other_service := StubService.new()
	autofree(other_service)
	U_SERVICE_LOCATOR.register(&"other_service", other_service)
	var result: Variant = _dep_res.resolve(&"test_service", null, null)
	assert_null(result, "Should return null for unregistered service")

# ─── resolve_state_store() — cached value ────────────────────────────────

func test_resolve_state_store_returns_cached_store() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var cached_store := StubStateStore.new()
	autofree(cached_store)
	var owner := StubOwner.new()
	autofree(owner)
	var result: I_StateStore = _dep_res.resolve_state_store(cached_store, null, owner)
	assert_same(result, cached_store, "Should return cached state store")

func test_resolve_state_store_returns_cached_store_over_export() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var cached_store := StubStateStore.new()
	autofree(cached_store)
	var export_store := StubStateStore.new()
	autofree(export_store)
	var owner := StubOwner.new()
	autofree(owner)
	var result: I_StateStore = _dep_res.resolve_state_store(cached_store, export_store, owner)
	assert_same(result, cached_store, "Cached store should take priority over export")

# ─── resolve_state_store() — export fallback ────────────────────────────

func test_resolve_state_store_returns_export_when_cache_null() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var export_store := StubStateStore.new()
	autofree(export_store)
	var owner := StubOwner.new()
	autofree(owner)
	var result: I_StateStore = _dep_res.resolve_state_store(null, export_store, owner)
	assert_same(result, export_store, "Should return export store when cache is null")

func test_resolve_state_store_returns_export_when_cache_freed() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var export_store := StubStateStore.new()
	autofree(export_store)
	var owner := StubOwner.new()
	autofree(owner)
	var freed_cache := StubStateStore.new()
	freed_cache.free()
	var result: I_StateStore = _dep_res.resolve_state_store(freed_cache, export_store, owner)
	assert_same(result, export_store, "Should skip freed cache and return export store")

# ─── resolve_state_store() — U_StateUtils fallback ──────────────────────

func test_resolve_state_store_falls_back_to_state_utils_when_owner_has_export() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var store := StubStateStore.new()
	autofree(store)
	var owner := StubOwner.new()
	autofree(owner)
	owner.state_store = store
	var result: I_StateStore = _dep_res.resolve_state_store(null, null, owner)
	assert_same(result, store, "Should find store via owner's state_store property")

func test_resolve_state_store_falls_back_to_service_locator() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var store := StubStateStore.new()
	autofree(store)
	U_SERVICE_LOCATOR.register(&"state_store", store)
	var owner := StubOwner.new()
	autofree(owner)
	var result: I_StateStore = _dep_res.resolve_state_store(null, null, owner)
	assert_same(result, store, "Should find store via ServiceLocator fallback")

# ─── resolve_state_store() — null when unavailable ───────────────────────

func test_resolve_state_store_returns_null_when_no_store_available() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var owner := StubOwner.new()
	autofree(owner)
	var result: I_StateStore = _dep_res.resolve_state_store(null, null, owner)
	assert_null(result, "Should return null when no state store is available")

func test_resolve_state_store_returns_null_when_owner_null() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var result: I_StateStore = _dep_res.resolve_state_store(null, null, null)
	assert_null(result, "Should return null when owner is null")

func test_resolve_state_store_returns_null_when_owner_not_node() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	# Non-Node value should return null (U_StateUtils requires a Node)
	var result: I_StateStore = _dep_res.resolve_state_store(null, null, "not_a_node")
	assert_null(result, "Should return null when owner is not a Node")

# ─── resolve() — generic service resolution for ECS manager ──────────

class StubECSManager extends Node:
	var service_name: String = "ecs_manager"

func test_resolve_finds_ecs_manager_via_service_locator() -> void:
	if _dep_res == null:
		pending("U_DependencyResolution not loaded")
		return
	var manager := StubECSManager.new()
	autofree(manager)
	U_SERVICE_LOCATOR.register(&"ecs_manager", manager)
	var result: Variant = _dep_res.resolve(&"ecs_manager", null, null)
	assert_same(result, manager, "Should resolve ECS manager via ServiceLocator")