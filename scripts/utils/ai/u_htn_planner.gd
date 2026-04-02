extends RefCounted
class_name U_HTNPlanner

const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const RS_AI_COMPOUND_TASK := preload("res://scripts/resources/ai/rs_ai_compound_task.gd")
const RS_RULE := preload("res://scripts/resources/qb/rs_rule.gd")

static func decompose(task: Resource, context: Dictionary, max_depth: int = 20) -> Array[Resource]:
	if task == null:
		return []

	var safe_max_depth: int = maxi(max_depth, 0)
	var recursion_stack: Dictionary = {}
	var result: Array[Resource] = []
	_decompose_recursive(task, context, safe_max_depth, 0, recursion_stack, result)
	return result

static func _decompose_recursive(
	task: Resource,
	context: Dictionary,
	max_depth: int,
	depth: int,
	recursion_stack: Dictionary,
	result: Array[Resource]
) -> void:
	if task == null:
		return
	if depth > max_depth:
		return

	if task is RS_AI_PRIMITIVE_TASK:
		result.append(task)
		return

	if not (task is RS_AI_COMPOUND_TASK):
		return
	if depth >= max_depth:
		return

	var task_object: Object = task as Object
	if task_object == null:
		return
	var task_key: int = task_object.get_instance_id()
	if recursion_stack.has(task_key):
		return
	
	recursion_stack[task_key] = true

	var subtasks: Array[Resource] = _read_resource_array(task, "subtasks")
	if subtasks.is_empty():
		recursion_stack.erase(task_key)
		return

	var method_conditions: Array[Resource] = _read_resource_array(task, "method_conditions")
	if method_conditions.is_empty():
		for subtask in subtasks:
			_decompose_recursive(subtask, context, max_depth, depth + 1, recursion_stack, result)
		recursion_stack.erase(task_key)
		return

	var branch_index: int = _select_branch_index(method_conditions, context, subtasks.size())
	if branch_index >= 0 and branch_index < subtasks.size():
		var selected_subtask: Resource = subtasks[branch_index]
		_decompose_recursive(selected_subtask, context, max_depth, depth + 1, recursion_stack, result)

	recursion_stack.erase(task_key)

static func _select_branch_index(method_conditions: Array[Resource], context: Dictionary, subtask_count: int) -> int:
	var condition_count: int = mini(method_conditions.size(), subtask_count)
	if condition_count <= 0:
		return -1

	var branch_rules: Array = []
	var rule_to_index: Dictionary = {}
	for index in range(condition_count):
		var condition: Resource = method_conditions[index]
		if condition == null:
			continue

		var method_rule: Resource = RS_RULE.new()
		method_rule.set("rule_id", StringName("__method_condition_%d" % index))
		var rule_conditions: Array[Resource] = [condition]
		method_rule.set("conditions", rule_conditions)
		method_rule.set("score_threshold", 0.0)

		branch_rules.append(method_rule)
		rule_to_index[method_rule] = index

	if branch_rules.is_empty():
		return -1

	var scored_results: Array[Dictionary] = U_RULE_SCORER.score_rules(branch_rules, context)
	for scored_entry in scored_results:
		var rule_variant: Variant = scored_entry.get("rule", null)
		if rule_variant == null or not rule_to_index.has(rule_variant):
			continue
		return int(rule_to_index.get(rule_variant, -1))

	return -1

static func _read_resource_array(resource: Resource, property_name: String) -> Array[Resource]:
	if resource == null:
		return []

	var value: Variant = resource.get(property_name)
	if not (value is Array):
		return []

	var resources: Array[Resource] = []
	for entry in value as Array:
		if entry == null or not (entry is Resource):
			continue
		resources.append(entry as Resource)
	return resources
