class_name U_EditorBlockoutBuilder
extends RefCounted

var _root: Node3D = null

func create_root(node_name: String) -> U_EditorBlockoutBuilder:
	var node: Node3D = Node3D.new()
	node.name = node_name
	_root = node
	return self

func add_csg_box(node_name: String, size: Vector3) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: add_csg_box called before create_root")
		return self
	var box: CSGBox3D = CSGBox3D.new()
	box.name = node_name
	box.size = size
	_root.add_child(box)
	return self

func add_csg_sphere(node_name: String, radius: float) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: add_csg_sphere called before create_root")
		return self
	var sphere: CSGSphere3D = CSGSphere3D.new()
	sphere.name = node_name
	sphere.radius = radius
	_root.add_child(sphere)
	return self

func add_spawn_point(node_name: String, position: Vector3) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: add_spawn_point called before create_root")
		return self
	var marker: Marker3D = Marker3D.new()
	marker.name = node_name
	marker.position = position
	_root.add_child(marker)
	return self

func execute_custom(callback: Callable) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: execute_custom called before create_root")
		return self
	callback.call(_root)
	return self

func save(save_path: String) -> bool:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: save() called before create_root()")
		return false
	for child in _root.get_children():
		_set_owner_recursive(child, _root)
	var packed: PackedScene = PackedScene.new()
	var pack_result: int = packed.pack(_root)
	if pack_result != OK:
		push_error("U_EditorBlockoutBuilder: pack() failed with code %d" % pack_result)
		return false
	var save_result: int = ResourceSaver.save(packed, save_path)
	if save_result != OK:
		push_error("U_EditorBlockoutBuilder: ResourceSaver.save() failed with code %d" % save_result)
		return false
	return true

func build() -> Node3D:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: build() called before create_root()")
		return null
	return _root

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.set_owner(owner)
	for child in node.get_children():
		_set_owner_recursive(child, owner)
