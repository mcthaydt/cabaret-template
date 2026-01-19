extends RefCounted
class_name U_StateUtils

## Utility functions for state management (similar to U_ECSUtils)
##
## Provides helpers for finding M_StateStore in scene tree and
## performance benchmarking for state operations.

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const STORE_GROUP := StringName("state_store")

## Get the I_StateStore from injection or ServiceLocator.
## Returns null if no store found or node is invalid.
##
## Lookup order (Phase 10B-8):
##   1. Check if node has 'state_store' @export (for test injection)
##   2. ServiceLocator (fast, centralized)
static func get_store(node: Node) -> I_StateStore:
	if node == null or not is_instance_valid(node):
		push_error("U_StateUtils.get_store: Invalid node")
		return null

	# Priority 1: Check for injected store (test pattern, Phase 10B-8)
	if "state_store" in node:
		var injected: Variant = node.get("state_store")
		if injected != null and is_instance_valid(injected):
			return injected

	# Priority 2: ServiceLocator (production pattern)
	var store := U_ServiceLocator.try_get_service(STORE_GROUP) as I_StateStore

	if store == null:
		push_error("U_StateUtils.get_store: No M_StateStore registered in ServiceLocator")

	return store

## Try to get the I_StateStore from injection or ServiceLocator (silent)
## Returns null if no store found or node is invalid.
##
## Lookup order:
##   1. Check if node has 'state_store' @export (for test injection)
##   2. ServiceLocator (fast, centralized)
static func try_get_store(node: Node) -> I_StateStore:
	if node == null or not is_instance_valid(node):
		return null

	# Priority 1: Check for injected store (test pattern, Phase 10B-8)
	if "state_store" in node:
		var injected: Variant = node.get("state_store")
		if injected != null and is_instance_valid(injected):
			return injected

	# Priority 2: ServiceLocator (production pattern)
	var store := U_ServiceLocator.try_get_service(STORE_GROUP) as I_StateStore
	if store != null:
		return store
	return null

static func await_store_ready(node: Node, max_frames: int = 120) -> I_StateStore:
	if node == null or not is_instance_valid(node):
		push_error("U_StateUtils.await_store_ready: Invalid node")
		return null

	var tree: SceneTree = node.get_tree()
	if tree == null:
		push_error("U_StateUtils.await_store_ready: Node not in tree")
		return null

	var frames_waited := 0
	while frames_waited <= max_frames:
		if node == null or not is_instance_valid(node):
			push_error("U_StateUtils.await_store_ready: Node became invalid while waiting")
			return null

		var store: I_StateStore = null
		if "state_store" in node:
			var injected: Variant = node.get("state_store")
			if injected != null and is_instance_valid(injected):
				store = injected as I_StateStore

		if store == null:
			# ServiceLocator may be registered on a later frame; recheck each loop.
			store = U_ServiceLocator.try_get_service(STORE_GROUP) as I_StateStore

		if store != null:
			if store.is_ready():
				return store
			await store.store_ready
			if is_instance_valid(store) and store.is_ready():
				return store
			# Store was freed before completing readiness; continue loop.
		await tree.process_frame
		frames_waited += 1

	push_error("U_StateUtils.await_store_ready: Timed out waiting for M_StateStore")
	return null

## Benchmark a callable and return elapsed time in milliseconds
## Useful for profiling state operations
static func benchmark(name: String, callable: Callable) -> float:
	if not callable.is_valid():
		push_warning("U_StateUtils.benchmark: Invalid callable")
		return 0.0
		
	var start: int = Time.get_ticks_usec()
	
	# Call with no arguments
	if callable.get_argument_count() == 0:
		callable.call()
	else:
		push_warning("U_StateUtils.benchmark: Callable expects arguments, calling with empty array")
		callable.callv([])
		
	var end: int = Time.get_ticks_usec()
	var elapsed_ms: float = (end - start) / 1000.0
	return elapsed_ms
