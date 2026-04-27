class_name U_EditorPrefabBuilder
extends RefCounted

var _root: Node = null

func create_root(node_type: String, node_name: String) -> U_EditorPrefabBuilder:
	var node: Node = ClassDB.instantiate(node_type) as Node
	if node == null:
		push_error("U_EditorPrefabBuilder: failed to instantiate node_type '%s'" % node_type)
		return self
	node.name = node_name
	_root = node
	return self

func inherit_from(scene_path: String) -> U_EditorPrefabBuilder:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("U_EditorPrefabBuilder: failed to load scene at '%s'" % scene_path)
		return self
	var instance: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node
	if instance == null:
		push_error("U_EditorPrefabBuilder: failed to instantiate scene from '%s'" % scene_path)
		return self
	_root = instance
	return self

func set_entity_id(id: StringName) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: set_entity_id called before root creation")
		return self
	_root.set_meta("entity_id", id)
	return self

func set_tags(tags: Array) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: set_tags called before root creation")
		return self
	_root.set_meta("tags", tags)
	return self

func build() -> Node:
	if _root == null:
		push_error("U_EditorPrefabBuilder: build() called before create_root() or inherit_from()")
		return null
	return _root
