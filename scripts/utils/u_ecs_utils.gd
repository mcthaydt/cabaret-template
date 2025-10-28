extends RefCounted

class_name U_ECSUtils

const META_ENTITY_ROOT := StringName("_ecs_entity_root")
const ENTITY_GROUP := StringName("ecs_entity")
const MANAGER_GROUP := StringName("ecs_manager")
const BASE_ENTITY_SCRIPT := preload("res://scripts/ecs/base_entity.gd")

static var _warning_handler: Callable = Callable()
static var _manager_method_warnings: Dictionary = {}

static func get_manager(from_node: Node) -> Node:
	if from_node == null:
		return null

	var current: Node = from_node.get_parent()
	while current != null:
		if _node_has_manager_methods(current):
			return current
		_warn_missing_manager_methods(current)
		current = current.get_parent()

	var manager: Node = get_singleton_from_group(from_node, MANAGER_GROUP, false)
	if manager != null:
		if _node_has_manager_methods(manager):
			return manager
		_warn_missing_manager_methods(manager)

	return null

static func find_entity_root(from_node: Node, warn_on_missing: bool = false) -> Node:
	if from_node == null:
		return null

	var visited: Array[Node] = []
	var current: Node = from_node
	while current != null:
		visited.append(current)
		if current.has_meta(META_ENTITY_ROOT):
			var stored_value: Variant = current.get_meta(META_ENTITY_ROOT)
			var stored_node: Node = stored_value as Node
			if stored_node != null and is_instance_valid(stored_node):
				return _cache_entity_root(stored_node, visited)

		var current_script: Script = current.get_script()
		if current_script == BASE_ENTITY_SCRIPT:
			return _cache_entity_root(current, visited)

		if current.is_in_group(ENTITY_GROUP):
			return _cache_entity_root(current, visited)

		if String(current.name).begins_with("E_"):
			return _cache_entity_root(current, visited)

		current = current.get_parent()

	if warn_on_missing:
		_emit_warning("U_ECSUtils: Node %s has no ECS entity root." % _describe_node(from_node))
	return null

static func get_current_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

static func map_components_by_body(manager: M_ECSManager, component_type: StringName) -> Dictionary:
	var result: Dictionary = {}
	if manager == null:
		return result

	var components: Array = manager.get_components(component_type)
	for entry in components:
		var ecs_component: BaseECSComponent = entry as BaseECSComponent
		if ecs_component == null:
			continue
		if not ecs_component.has_method("get_character_body"):
			continue

		var body: Node = ecs_component.get_character_body()
		if body == null:
			continue

		result[body] = ecs_component

	return result

static func get_singleton_from_group(from_node: Node, group_name: StringName, warn_on_missing: bool = true) -> Node:
	if from_node == null:
		return null

	var tree: SceneTree = from_node.get_tree()
	if tree == null:
		return null

	var nodes: Array = tree.get_nodes_in_group(group_name)
	if not nodes.is_empty():
		return nodes[0]

	if warn_on_missing:
		_emit_warning("U_ECSUtils: No node found in group '%s'" % String(group_name))
	return null

static func get_nodes_from_group(from_node: Node, group_name: StringName) -> Array:
	if from_node == null:
		return []

	var tree: SceneTree = from_node.get_tree()
	if tree == null:
		return []

	var nodes: Array = tree.get_nodes_in_group(group_name)
	return nodes.duplicate()

static func get_active_camera(from_node: Node) -> Camera3D:
	if from_node == null:
		return null

	var viewport: Viewport = from_node.get_viewport()
	if viewport != null:
		var viewport_camera: Camera3D = viewport.get_camera_3d()
		if viewport_camera != null:
			return viewport_camera

	return get_singleton_from_group(from_node, StringName("main_camera"), false) as Camera3D

static func set_warning_handler(handler: Callable) -> void:
	_warning_handler = handler

static func reset_warning_handler() -> void:
	_warning_handler = Callable()

static func _node_has_manager_methods(candidate: Node) -> bool:
	if candidate == null:
		return false
	return candidate.has_method("register_component") and candidate.has_method("register_system")

static func _cache_entity_root(entity: Node, visited: Array[Node]) -> Node:
	if entity == null:
		return null
	entity.set_meta(META_ENTITY_ROOT, entity)
	for node in visited:
		if node == null:
			continue
		node.set_meta(META_ENTITY_ROOT, entity)
	return entity

static func _warn_missing_manager_methods(candidate: Node) -> void:
	if candidate == null:
		return
	if not _should_emit_debug_warning():
		return
	if not _is_potential_manager(candidate):
		return

	var key: String = "missing_manager_methods:%d" % candidate.get_instance_id()
	if _manager_method_warnings.has(key):
		return
	_manager_method_warnings[key] = true

	var identifier: String = String(candidate.name)
	if candidate.is_inside_tree():
		identifier = String(candidate.get_path())

	_emit_warning("U_ECSUtils: Node '%s' looks like an ECS manager but is missing required methods." % String(identifier))

static func _is_potential_manager(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate is M_ECSManager:
		return true
	if candidate.is_in_group(MANAGER_GROUP):
		return true
	return String(candidate.name).begins_with("M_")

static func _should_emit_debug_warning() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

static func _describe_node(node: Node) -> String:
	if node == null:
		return "<null>"
	if node.is_inside_tree():
		return String(node.get_path())
	return "%s(%d)" % [String(node.name), node.get_instance_id()]

static func _emit_warning(message: String) -> void:
	if _warning_handler != Callable() and _warning_handler.is_valid():
		_warning_handler.call(message)
	else:
		push_warning(message)
