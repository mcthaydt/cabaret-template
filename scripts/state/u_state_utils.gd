extends RefCounted
class_name U_StateUtils

## Utility functions for state management (similar to U_ECSUtils)
##
## Provides helpers for finding M_StateStore in scene tree and
## performance benchmarking for state operations.

const STORE_GROUP := StringName("state_store")

## Get the M_StateStore from the scene tree
## Returns null if no store found or node is invalid
static func get_store(node: Node) -> M_StateStore:
	if node == null or not is_instance_valid(node):
		push_error("U_StateUtils.get_store: Invalid node")
		return null

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

	return store_group[0] as M_StateStore

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
	if OS.is_debug_build():
		print("[BENCHMARK] %s: %.3f ms" % [name, elapsed_ms])
	return elapsed_ms
