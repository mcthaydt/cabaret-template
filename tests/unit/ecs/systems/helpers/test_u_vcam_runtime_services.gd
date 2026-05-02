extends GutTest

## Tests for U_VCamRuntimeServices.resolve_state_store delegation to U_DependencyResolution.
##
## Verifies that the runtime services' state store resolution uses the shared
## U_DependencyResolution utility instead of inline U_STATE_UTILS.try_get_store.

const U_VCAM_RUNTIME_SERVICES := preload("res://scripts/core/ecs/systems/helpers/u_vcam_runtime_services.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_STATE_STORE := preload("res://scripts/core/interfaces/i_state_store.gd")

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

func before_each() -> void:
	super.before_each()
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	super.after_each()
	U_SERVICE_LOCATOR.clear()

# ─── resolve_state_store delegation ───────────────────────────────────

func test_resolve_state_store_delegates_to_dependency_resolution_with_cache() -> void:
	var services := U_VCAM_RUNTIME_SERVICES.new()
	var owner := StubOwner.new()
	autofree(owner)
	services.configure(owner, null, null)

	var store := StubStateStore.new()
	autofree(store)
	# Inject a cached store via the internal variable
	services._state_store = store

	var result: I_StateStore = services.resolve_state_store()
	assert_same(result, store, "Should return cached store via U_DependencyResolution")

func test_resolve_state_store_delegates_to_dependency_resolution_with_export() -> void:
	var services := U_VCAM_RUNTIME_SERVICES.new()
	var owner := StubOwner.new()
	autofree(owner)

	var export_store := StubStateStore.new()
	autofree(export_store)
	services.configure(owner, export_store, null)

	var result: I_StateStore = services.resolve_state_store()
	assert_same(result, export_store, "Should return exported store via U_DependencyResolution")

func test_resolve_state_store_delegates_to_dependency_resolution_service_locator() -> void:
	var services := U_VCAM_RUNTIME_SERVICES.new()
	var owner := StubOwner.new()
	autofree(owner)
	services.configure(owner, null, null)

	var store := StubStateStore.new()
	autofree(store)
	U_SERVICE_LOCATOR.register(&"state_store", store)

	var result: I_StateStore = services.resolve_state_store()
	assert_same(result, store, "Should find store via ServiceLocator fallback through U_DependencyResolution")

func test_resolve_state_store_returns_null_when_nothing_available() -> void:
	var services := U_VCAM_RUNTIME_SERVICES.new()
	var owner := StubOwner.new()
	autofree(owner)
	services.configure(owner, null, null)

	var result: I_StateStore = services.resolve_state_store()
	assert_null(result, "Should return null when no store is available")

func test_resolve_state_store_caches_result() -> void:
	var services := U_VCAM_RUNTIME_SERVICES.new()
	var owner := StubOwner.new()
	autofree(owner)

	var export_store := StubStateStore.new()
	autofree(export_store)
	services.configure(owner, export_store, null)

	var _first: I_StateStore = services.resolve_state_store()
	var second: I_StateStore = services.resolve_state_store()
	assert_same(second, export_store, "Should return cached result on second call")