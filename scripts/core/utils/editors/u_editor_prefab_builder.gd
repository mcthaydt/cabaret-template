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

func add_ecs_component(script: Script, settings: Resource = null, properties: Dictionary = {}) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_ecs_component called before root creation")
		return self
	_components_container()
	var components: Node = _root.get_node("Components")
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
