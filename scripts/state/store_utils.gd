extends RefCounted
class_name StateStoreUtils

static func get_store(from_node: Node) -> Node:
	var current: Node = from_node.get_parent()
	while current != null:
		if current.has_method("dispatch") and current.has_method("subscribe"):
			return current
		current = current.get_parent()

	var tree := from_node.get_tree()
	if tree == null:
		assert(false, "StateStore not found in scene tree")
		return null

	var stores: Array = tree.get_nodes_in_group("state_store")
	if stores.size() > 0:
		return stores[0]

	assert(false, "StateStore not found in scene tree")
	return null
