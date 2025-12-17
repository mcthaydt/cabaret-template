extends RefCounted
class_name U_StateUtils

## Utility functions for state management (similar to U_ECSUtils)
##
## Provides helpers for finding M_StateStore in scene tree and
## performance benchmarking for state operations.

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const STORE_GROUP := StringName("state_store")

## Get the M_StateStore from the ServiceLocator
## Returns null if no store found or node is invalid
static func get_store(node: Node) -> M_StateStore:
	if node == null or not is_instance_valid(node):
		push_error("U_StateUtils.get_store: Invalid node")
		return null

	# Use ServiceLocator for fast, centralized lookup (try_get_service for silent fallback)
	var store := U_ServiceLocator.try_get_service(STORE_GROUP) as M_StateStore

	# Fallback to group lookup for backward compatibility during migration
	if store == null:
		var tree: SceneTree = node.get_tree()
		if tree == null:
			push_error("U_StateUtils.get_store: Node not in tree")
			return null

		var store_group: Array = tree.get_nodes_in_group(STORE_GROUP)
		if store_group.is_empty():
			push_error("U_StateUtils.get_store: No M_StateStore in 'state_store' group")
			return null

		if store_group.size() > 1:
			push_warning("U_StateUtils.get_store: Multiple stores found, using first")

		store = store_group[0] as M_StateStore

	return store

static func await_store_ready(node: Node, max_frames: int = 120) -> M_StateStore:
	if node == null or not is_instance_valid(node):
		push_error("U_StateUtils.await_store_ready: Invalid node")
		return null

	var tree: SceneTree = node.get_tree()
	if tree == null:
		push_error("U_StateUtils.await_store_ready: Node not in tree")
		return null

	var frames_waited := 0
	while frames_waited <= max_frames:
		# Try ServiceLocator first (silent lookup to avoid error spam during waiting)
		var store := U_ServiceLocator.try_get_service(STORE_GROUP) as M_StateStore

		# Fallback to group lookup if ServiceLocator not initialized yet
		if store == null:
			store = tree.get_first_node_in_group(STORE_GROUP) as M_StateStore

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
