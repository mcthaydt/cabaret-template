class_name U_DisplayApplierUtils

## Shared utilities for display applier classes.


static func get_tree_safe(owner: Node) -> SceneTree:
	if owner != null:
		return owner.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null
