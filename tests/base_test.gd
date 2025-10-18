extends GutTest
class_name BaseTest

## Base test class that centralizes automatic cleanup of test fixtures.
## Registers created nodes with GUT's autofree queue so they are cleaned up
## even when tests fail early.

## Register a single node for queue_free cleanup after the test finishes.
func autofree(node: Node) -> Node:
	var auto_free: RefCounted = gut.get_autofree()
	auto_free.add_queue_free(node)
	return node

## Register every Node value contained in a context dictionary.
func autofree_context(context: Dictionary) -> void:
	var auto_free: RefCounted = gut.get_autofree()
	for value in context.values():
		if value is Node:
			auto_free.add_queue_free(value)

## Register all nodes contained in an array for cleanup.
func autofree_all(nodes: Array) -> void:
	var auto_free: RefCounted = gut.get_autofree()
	for node in nodes:
		if node is Node:
			auto_free.add_queue_free(node)
