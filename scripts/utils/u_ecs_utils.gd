extends RefCounted

class_name U_ECSUtils

static func get_manager(from_node: Node) -> Node:
	if from_node == null:
		return null

	var current := from_node.get_parent()
	while current != null:
		if current.has_method("register_component") and current.has_method("register_system"):
			return current
		current = current.get_parent()

	var tree := from_node.get_tree()
	if tree == null:
		return null

	var managers := tree.get_nodes_in_group("ecs_manager")
	for manager in managers:
		if manager.has_method("register_component") and manager.has_method("register_system"):
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
