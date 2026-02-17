extends RefCounted
class_name U_LocalizationRootRegistry

## Centralized registry for localization UI roots.
## Handles duplicate prevention, dead-node pruning, and locale-change notifications.

var _roots: Array[Node] = []

func register_root(root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	_prune_dead_roots()
	if root in _roots:
		return false
	_roots.append(root)
	return true

func unregister_root(root: Node) -> bool:
	if root == null:
		return false
	_prune_dead_roots()
	if root not in _roots:
		return false
	_roots.erase(root)
	return true

func get_live_roots() -> Array[Node]:
	_prune_dead_roots()
	return _roots.duplicate()

func notify_locale_changed(locale: StringName) -> void:
	_prune_dead_roots()
	for root: Node in _roots:
		if root.has_method("_on_locale_changed"):
			root._on_locale_changed(locale)

func clear() -> void:
	_roots.clear()

func _prune_dead_roots() -> void:
	var live_roots: Array[Node] = []
	for root: Node in _roots:
		if is_instance_valid(root):
			live_roots.append(root)
	_roots = live_roots
