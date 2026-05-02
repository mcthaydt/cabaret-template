extends GutTest

const OBJECTIVE_GRAPH := preload("res://scripts/core/utils/scene_director/u_objective_graph.gd")
const OBJECTIVE_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_objective_definition.gd")

func test_build_graph_maps_dependencies_and_dependents() -> void:
	var objectives: Array[Resource] = [
		_objective(StringName("obj_a"), []),
		_objective(StringName("obj_b"), [StringName("obj_a")]),
		_objective(StringName("obj_c"), [StringName("obj_a"), StringName("obj_b")]),
	]
	var graph: Dictionary = OBJECTIVE_GRAPH.build_graph(objectives)

	assert_true(graph.has(StringName("obj_a")))
	assert_true(graph.has(StringName("obj_b")))
	assert_true(graph.has(StringName("obj_c")))

	var node_a: Dictionary = graph.get(StringName("obj_a"), {})
	var node_b: Dictionary = graph.get(StringName("obj_b"), {})
	var node_c: Dictionary = graph.get(StringName("obj_c"), {})

	assert_eq(node_a.get("dependencies", []), [])
	assert_true((node_a.get("dependents", []) as Array).has(StringName("obj_b")))
	assert_true((node_a.get("dependents", []) as Array).has(StringName("obj_c")))
	assert_true((node_b.get("dependencies", []) as Array).has(StringName("obj_a")))
	assert_true((node_b.get("dependents", []) as Array).has(StringName("obj_c")))
	assert_true((node_c.get("dependencies", []) as Array).has(StringName("obj_a")))
	assert_true((node_c.get("dependencies", []) as Array).has(StringName("obj_b")))

func test_validate_graph_reports_missing_dependencies() -> void:
	var objectives: Array[Resource] = [
		_objective(StringName("obj_a"), [StringName("obj_missing")]),
	]
	var graph: Dictionary = OBJECTIVE_GRAPH.build_graph(objectives)
	var known_ids: Array[StringName] = [StringName("obj_a")]
	var errors: Array[String] = OBJECTIVE_GRAPH.validate_graph(graph, known_ids)

	assert_gt(errors.size(), 0, "Expected missing dependency error")
	assert_true(
		_contains_message(errors, "obj_missing"),
		"Expected error text to include missing dependency id"
	)

func test_validate_graph_reports_cycles() -> void:
	var objectives: Array[Resource] = [
		_objective(StringName("obj_a"), [StringName("obj_c")]),
		_objective(StringName("obj_b"), [StringName("obj_a")]),
		_objective(StringName("obj_c"), [StringName("obj_b")]),
	]
	var graph: Dictionary = OBJECTIVE_GRAPH.build_graph(objectives)
	var known_ids: Array[StringName] = [
		StringName("obj_a"),
		StringName("obj_b"),
		StringName("obj_c"),
	]
	var errors: Array[String] = OBJECTIVE_GRAPH.validate_graph(graph, known_ids)

	assert_gt(errors.size(), 0, "Expected cycle detection error")
	assert_true(_contains_message(errors, "cycle"), "Expected error text to mention cycle")

func test_get_ready_dependents_requires_all_prerequisites_completed() -> void:
	var objectives: Array[Resource] = [
		_objective(StringName("obj_a"), []),
		_objective(StringName("obj_b"), [StringName("obj_a")]),
		_objective(StringName("obj_c"), [StringName("obj_a"), StringName("obj_b")]),
	]
	var graph: Dictionary = OBJECTIVE_GRAPH.build_graph(objectives)

	var statuses_after_a := {
		StringName("obj_a"): "completed",
		StringName("obj_b"): "inactive",
		StringName("obj_c"): "inactive",
	}
	var ready_after_a: Array[StringName] = OBJECTIVE_GRAPH.get_ready_dependents(
		StringName("obj_a"),
		graph,
		statuses_after_a
	)
	assert_eq(ready_after_a, [StringName("obj_b")])

	var statuses_after_b := {
		StringName("obj_a"): "completed",
		StringName("obj_b"): "completed",
		StringName("obj_c"): "inactive",
	}
	var ready_after_b: Array[StringName] = OBJECTIVE_GRAPH.get_ready_dependents(
		StringName("obj_b"),
		graph,
		statuses_after_b
	)
	assert_eq(ready_after_b, [StringName("obj_c")])

func test_topological_sort_returns_dependency_safe_order() -> void:
	var objectives: Array[Resource] = [
		_objective(StringName("obj_a"), []),
		_objective(StringName("obj_b"), [StringName("obj_a")]),
		_objective(StringName("obj_c"), [StringName("obj_b")]),
		_objective(StringName("obj_d"), [StringName("obj_a")]),
	]
	var graph: Dictionary = OBJECTIVE_GRAPH.build_graph(objectives)
	var order: Array[StringName] = OBJECTIVE_GRAPH.topological_sort(graph)

	assert_eq(order.size(), 4)
	assert_true(order.has(StringName("obj_a")))
	assert_true(order.has(StringName("obj_b")))
	assert_true(order.has(StringName("obj_c")))
	assert_true(order.has(StringName("obj_d")))
	assert_lt(order.find(StringName("obj_a")), order.find(StringName("obj_b")))
	assert_lt(order.find(StringName("obj_b")), order.find(StringName("obj_c")))
	assert_lt(order.find(StringName("obj_a")), order.find(StringName("obj_d")))

func _objective(objective_id: StringName, dependencies: Array[StringName]) -> Resource:
	var objective: Resource = OBJECTIVE_DEFINITION.new()
	objective.objective_id = objective_id
	objective.dependencies = dependencies.duplicate()
	return objective

func _contains_message(messages: Array[String], needle: String) -> bool:
	var target := needle.to_lower()
	for message in messages:
		if message.to_lower().contains(target):
			return true
	return false
