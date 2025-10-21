extends RefCounted

class_name U_ECSUtils

static var _warning_handler: Callable = Callable()

static func get_manager(from_node: Node) -> Node:
	if from_node == null:
		return null

	var current := from_node.get_parent()
	while current != null:
		if current.has_method("register_component") and current.has_method("register_system"):
			return current
		current = current.get_parent()

	var manager := get_singleton_from_group(from_node, StringName("ecs_manager"), false)
	if manager != null and manager.has_method("register_component") and manager.has_method("register_system"):
		return manager

	return null

static func get_current_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

static func map_components_by_body(manager: M_ECSManager, component_type: StringName) -> Dictionary:
	var result: Dictionary = {}
	if manager == null:
		return result

	var components: Array = manager.get_components(component_type)
	for entry in components:
		var ecs_component: ECSComponent = entry as ECSComponent
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

	var tree := from_node.get_tree()
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

	var tree := from_node.get_tree()
	if tree == null:
		return []

	var nodes: Array = tree.get_nodes_in_group(group_name)
	return nodes.duplicate()

static func get_active_camera(from_node: Node) -> Camera3D:
	if from_node == null:
		return null

	var viewport := from_node.get_viewport()
	if viewport != null:
		var viewport_camera := viewport.get_camera_3d()
		if viewport_camera != null:
			return viewport_camera

	return get_singleton_from_group(from_node, StringName("main_camera"), false) as Camera3D

static func set_warning_handler(handler: Callable) -> void:
	_warning_handler = handler

static func reset_warning_handler() -> void:
	_warning_handler = Callable()

static func _emit_warning(message: String) -> void:
	if _warning_handler != Callable() and _warning_handler.is_valid():
		_warning_handler.call(message)
	else:
		push_warning(message)
