extends RefCounted
class_name U_ObjectiveGraph

static func build_graph(objectives: Array[Resource]) -> Dictionary:
	var graph: Dictionary = {}

	for objective_resource in objectives:
		if objective_resource == null:
			continue
		var objective_id: StringName = _to_string_name(objective_resource.get("objective_id"))
		if objective_id == StringName(""):
			continue
		if not graph.has(objective_id):
			graph[objective_id] = {
				"dependencies": [],
				"dependents": [],
			}

	for objective_resource in objectives:
		if objective_resource == null:
			continue
		var objective_id: StringName = _to_string_name(objective_resource.get("objective_id"))
		if objective_id == StringName("") or not graph.has(objective_id):
			continue

		var node: Dictionary = graph.get(objective_id, {}) as Dictionary
		var dependencies: Array[StringName] = _sanitize_dependency_ids(
			_resource_get(objective_resource, "dependencies", [])
		)
		node["dependencies"] = dependencies.duplicate()
		graph[objective_id] = node

		for dependency_id in dependencies:
			if not graph.has(dependency_id):
				continue
			var dependency_node: Dictionary = graph.get(dependency_id, {}) as Dictionary
			var dependents: Array[StringName] = _sanitize_string_name_array(dependency_node.get("dependents", []))
			if not dependents.has(objective_id):
				dependents.append(objective_id)
				dependents.sort()
			dependency_node["dependents"] = dependents
			graph[dependency_id] = dependency_node

	return graph

static func validate_graph(graph: Dictionary, known_ids: Array[StringName]) -> Array[String]:
	var errors: Array[String] = []
	var node_ids: Array[StringName] = _get_sorted_node_ids(graph)
	var known_lookup: Dictionary = {}
	for known_id in known_ids:
		known_lookup[known_id] = true

	for node_id in node_ids:
		var dependencies: Array[StringName] = _get_dependencies(graph, node_id)
		for dependency_id in dependencies:
			if known_lookup.has(dependency_id):
				continue
			var missing_error: String = "Missing dependency '%s' referenced by '%s'" % [
				String(dependency_id),
				String(node_id),
			]
			if not errors.has(missing_error):
				errors.append(missing_error)

	var visit_state: Dictionary = {}
	var dfs_stack: Array[StringName] = []
	for node_id in node_ids:
		if int(visit_state.get(node_id, 0)) == 0:
			_collect_cycle_errors(graph, node_id, visit_state, dfs_stack, errors)

	return errors

static func get_ready_dependents(
	objective_id: StringName,
	graph: Dictionary,
	statuses: Dictionary
) -> Array[StringName]:
	if not graph.has(objective_id):
		return []

	var ready: Array[StringName] = []
	var dependents: Array[StringName] = _get_dependents(graph, objective_id)
	for dependent_id in dependents:
		if _get_status_text(statuses, dependent_id) != "inactive":
			continue

		var dependencies: Array[StringName] = _get_dependencies(graph, dependent_id)
		var is_ready: bool = true
		for dependency_id in dependencies:
			if _get_status_text(statuses, dependency_id) != "completed":
				is_ready = false
				break
		if is_ready:
			ready.append(dependent_id)

	ready.sort()
	return ready

static func topological_sort(graph: Dictionary) -> Array[StringName]:
	var sorted_ids: Array[StringName] = []
	var node_ids: Array[StringName] = _get_sorted_node_ids(graph)
	if node_ids.is_empty():
		return sorted_ids

	var in_degree: Dictionary = {}
	for node_id in node_ids:
		in_degree[node_id] = 0

	for node_id in node_ids:
		var dependencies: Array[StringName] = _get_dependencies(graph, node_id)
		var degree: int = int(in_degree.get(node_id, 0))
		for dependency_id in dependencies:
			if graph.has(dependency_id):
				degree += 1
		in_degree[node_id] = degree

	var ready_queue: Array[StringName] = []
	for node_id in node_ids:
		if int(in_degree.get(node_id, 0)) == 0:
			ready_queue.append(node_id)
	ready_queue.sort()

	while not ready_queue.is_empty():
		var current: StringName = ready_queue.pop_front()
		sorted_ids.append(current)

		var dependents: Array[StringName] = _get_dependents(graph, current)
		for dependent_id in dependents:
			if not in_degree.has(dependent_id):
				continue
			var next_degree: int = int(in_degree.get(dependent_id, 0)) - 1
			in_degree[dependent_id] = next_degree
			if next_degree == 0:
				_insert_sorted_unique(ready_queue, dependent_id)

	if sorted_ids.size() == node_ids.size():
		return sorted_ids

	for node_id in node_ids:
		if not sorted_ids.has(node_id):
			sorted_ids.append(node_id)
	return sorted_ids

static func _collect_cycle_errors(
	graph: Dictionary,
	node_id: StringName,
	visit_state: Dictionary,
	dfs_stack: Array[StringName],
	errors: Array[String]
) -> void:
	visit_state[node_id] = 1
	dfs_stack.append(node_id)

	var dependencies: Array[StringName] = _get_dependencies(graph, node_id)
	for dependency_id in dependencies:
		if not graph.has(dependency_id):
			continue

		var state: int = int(visit_state.get(dependency_id, 0))
		if state == 0:
			_collect_cycle_errors(graph, dependency_id, visit_state, dfs_stack, errors)
			continue
		if state == 1:
			var cycle_text: String = _build_cycle_text(dfs_stack, dependency_id)
			if cycle_text != "" and not errors.has(cycle_text):
				errors.append(cycle_text)

	dfs_stack.pop_back()
	visit_state[node_id] = 2

static func _build_cycle_text(stack: Array[StringName], repeated_id: StringName) -> String:
	var start_index: int = stack.find(repeated_id)
	if start_index < 0:
		return ""

	var cycle_nodes: Array[StringName] = []
	for index in range(start_index, stack.size()):
		cycle_nodes.append(stack[index])
	cycle_nodes.append(repeated_id)

	var tokens: PackedStringArray = PackedStringArray()
	for node_id in cycle_nodes:
		tokens.append(String(node_id))

	return "Cycle detected: %s" % " -> ".join(tokens)

static func _get_sorted_node_ids(graph: Dictionary) -> Array[StringName]:
	var node_ids: Array[StringName] = []
	for raw_id in graph.keys():
		node_ids.append(_to_string_name(raw_id))
	node_ids.sort()
	return node_ids

static func _get_dependencies(graph: Dictionary, node_id: StringName) -> Array[StringName]:
	if not graph.has(node_id):
		return []
	var node: Dictionary = graph.get(node_id, {}) as Dictionary
	return _sanitize_dependency_ids(node.get("dependencies", []))

static func _get_dependents(graph: Dictionary, node_id: StringName) -> Array[StringName]:
	if not graph.has(node_id):
		return []
	var node: Dictionary = graph.get(node_id, {}) as Dictionary
	var dependents: Array[StringName] = _sanitize_dependency_ids(node.get("dependents", []))
	dependents.sort()
	return dependents

static func _sanitize_dependency_ids(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = _sanitize_string_name_array(value)
	var unique: Array[StringName] = []
	for id_value in ids:
		if id_value == StringName(""):
			continue
		if not unique.has(id_value):
			unique.append(id_value)
	unique.sort()
	return unique

static func _sanitize_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry in value:
			result.append(_to_string_name(entry))
	elif value is PackedStringArray:
		for entry in value:
			result.append(StringName(entry))
	return result

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback

	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value

static func _get_status_text(statuses: Dictionary, objective_id: StringName) -> String:
	if statuses.has(objective_id):
		return String(statuses.get(objective_id, "")).to_lower()

	var objective_key: String = String(objective_id)
	if statuses.has(objective_key):
		return String(statuses.get(objective_key, "")).to_lower()

	return "inactive"

static func _insert_sorted_unique(values: Array[StringName], item: StringName) -> void:
	if values.has(item):
		return

	values.append(item)
	values.sort()
