class_name U_EditorPrefabBuilder
extends RefCounted
const _ShapeFactory = preload("res://scripts/core/utils/editors/u_editor_shape_factory.gd")
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
func add_ecs_component(script: Script, settings: Resource = null, properties: Dictionary = {}) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_ecs_component called before root creation")
		return self
	var components: Node = _components_container()
	var component: Node = Node.new()
	component.set_script(script)
	var component_name: String = StringName(component.get("COMPONENT_TYPE")) if component.get("COMPONENT_TYPE") != null else script.resource_path.get_file().get_basename()
	component.name = component_name
	if settings != null and component.get_property_list().any(func(p): return p.name == "settings"):
		component.set("settings", settings)
	for key in properties:
		component.set(key, properties[key])
	components.add_child(component)
	return self
func add_ecs_component_by_path(script_path: String, settings_path: String = "", properties: Dictionary = {}) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_ecs_component_by_path called before root creation")
		return self
	var script: Script = load(script_path) as Script
	if script == null:
		push_error("U_EditorPrefabBuilder: failed to load script at '%s'" % script_path)
		return self
	var settings: Resource = null
	if settings_path != "":
		settings = load(settings_path) as Resource
	return add_ecs_component(script, settings, properties)
func add_visual_mesh(node_name: String, material: Material = null, scale: Vector3 = Vector3.ONE) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_visual_mesh called before root creation")
		return self
	_root.add_child(_ShapeFactory.create_visual_mesh(node_name, material, scale))
	return self
func add_collision_capsule(radius: float, height: float, shape_name: String = "CollisionShape3D") -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_collision_capsule called before root creation")
		return self
	_root.add_child(_ShapeFactory.create_collision_capsule(radius, height, shape_name))
	return self
func add_marker(marker_name: String) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_marker called before root creation")
		return self
	var marker: Marker3D = Marker3D.new()
	marker.name = marker_name
	_root.add_child(marker)
	return self
func override_property(node_path: String, property: StringName, value: Variant) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: override_property called before root creation")
		return self
	var target: Node = _root.get_node(node_path) if node_path != "." else _root
	if target == null:
		push_error("U_EditorPrefabBuilder: override_property target not found at '%s'" % node_path)
		return self
	var current_value: Variant = target.get(property)
	if current_value is Array and value is Array:
		(current_value as Array).assign(value)
		target.set(property, current_value)
		return self
	target.set(property, value)
	return self
func add_child_scene(scene_path: String, child_name: String) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_child_scene called before root creation")
		return self
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("U_EditorPrefabBuilder: failed to load child scene at '%s'" % scene_path)
		return self
	var instance: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node
	if instance == null:
		push_error("U_EditorPrefabBuilder: failed to instantiate child scene from '%s'" % scene_path)
		return self
	instance.name = child_name
	_root.add_child(instance)
	return self
func add_child_to(parent_path: String, node: Node) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_child_to called before root creation")
		return self
	var parent: Node = _root.get_node_or_null(parent_path) if parent_path != "." else _root
	if parent == null:
		push_error("U_EditorPrefabBuilder: add_child_to parent not found at '%s'" % parent_path)
		return self
	parent.add_child(node)
	return self
func add_child_scene_to(parent_path: String, scene_path: String, child_name: String) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_child_scene_to called before root creation")
		return self
	var parent: Node = _root.get_node_or_null(parent_path) if parent_path != "." else _root
	if parent == null:
		push_error("U_EditorPrefabBuilder: add_child_scene_to parent not found at '%s'" % parent_path)
		return self
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("U_EditorPrefabBuilder: failed to load child scene at '%s'" % scene_path)
		return self
	var instance: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node
	if instance == null:
		push_error("U_EditorPrefabBuilder: failed to instantiate child scene from '%s'" % scene_path)
		return self
	instance.name = child_name
	parent.add_child(instance)
	return self
func add_csg_box(name: String, size: Vector3, color: Color) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_csg_box called before root creation")
		return self
	_root.add_child(_ShapeFactory.create_csg_box(name, size, color))
	return self
func add_csg_sphere(name: String, radius: float, color: Color) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_csg_sphere called before root creation")
		return self
	_root.add_child(_ShapeFactory.create_csg_sphere(name, radius, color))
	return self
func add_csg_cylinder(name: String, radius: float, height: float, color: Color) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_csg_cylinder called before root creation")
		return self
	_root.add_child(_ShapeFactory.create_csg_cylinder(name, radius, height, color))
	return self
func add_collision_box(shape_name: String, size: Vector3) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_collision_box called before root creation")
		return self
	_root.add_child(_ShapeFactory.create_collision_box(shape_name, size))
	return self
func save(save_path: String) -> bool:
	if _root == null:
		push_error("U_EditorPrefabBuilder: save() called before create_root() or inherit_from()")
		return false
	for child in _root.get_children():
		_set_owner_recursive(child, _root)
	var packed: PackedScene = PackedScene.new()
	var pack_result: int = packed.pack(_root)
	if pack_result != OK:
		push_error("U_EditorPrefabBuilder: pack() failed with code %d" % pack_result)
		return false
	var save_result: int = ResourceSaver.save(packed, save_path)
	if save_result != OK:
		push_error("U_EditorPrefabBuilder: ResourceSaver.save() failed with code %d" % save_result)
		return false
	return true
func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.set_owner(owner)
	if node.get_scene_file_path() != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
func build() -> Node:
	if _root == null:
		push_error("U_EditorPrefabBuilder: build() called before create_root() or inherit_from()")
		return null
	return _root
func _components_container() -> Node:
	if _root.has_node("Components"):
		return _root.get_node("Components")
	var container: Node = Node.new()
	container.name = "Components"
	_root.add_child(container)
	return container
