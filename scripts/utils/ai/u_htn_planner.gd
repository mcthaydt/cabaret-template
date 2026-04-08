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
	var reusable_rule: Resource = RS_RULE.new()
	_decompose_recursive(task, context, safe_max_depth, 0, recursion_stack, result, reusable_rule)
	return result

static func _decompose_recursive(
	task: Resource,
	context: Dictionary,
	max_depth: int,
	depth: int,
	recursion_stack: Dictionary,
	result: Array[Resource],
	reusable_rule: Resource
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

	var subtasks: Array = _read_variant_array(task, "subtasks")
	if subtasks.is_empty():
		recursion_stack.erase(task_key)
		return

	var method_conditions: Array = _read_variant_array(task, "method_conditions")
	if method_conditions.is_empty():
		for subtask_variant in subtasks:
			if not (subtask_variant is Resource):
				continue
			_decompose_recursive(subtask_variant as Resource, context, max_depth, depth + 1, recursion_stack, result, reusable_rule)
		recursion_stack.erase(task_key)
		return

	var branch_index: int = _select_branch_index(method_conditions, subtasks, context, reusable_rule)
	if branch_index >= 0 and branch_index < subtasks.size():
		var selected_subtask: Variant = subtasks[branch_index]
		if selected_subtask is Resource:
			_decompose_recursive(selected_subtask as Resource, context, max_depth, depth + 1, recursion_stack, result, reusable_rule)

	recursion_stack.erase(task_key)

static func _select_branch_index(method_conditions: Array, subtasks: Array, context: Dictionary, reusable_rule: Resource) -> int:
	var slot_count: int = mini(method_conditions.size(), subtasks.size())
	if slot_count <= 0:
		return -1

	for index in range(slot_count):
		var subtask_variant: Variant = subtasks[index]
		if not (subtask_variant is Resource):
			continue
		var condition_variant: Variant = method_conditions[index]
		if not (condition_variant is Resource):
			continue
		if _method_condition_passes(condition_variant as Resource, context, index, reusable_rule):
			return index

	return -1

static func _method_condition_passes(condition: Resource, context: Dictionary, method_index: int, reusable_rule: Resource) -> bool:
	var method_rule: Resource = reusable_rule
	method_rule.set("rule_id", StringName("__method_condition_%d" % method_index))
	var rule_conditions: Array[Resource] = [condition]
	method_rule.set("conditions", rule_conditions)
	method_rule.set("score_threshold", 0.0)
	var scored_results: Array[Dictionary] = U_RULE_SCORER.score_rules([method_rule], context)
	return not scored_results.is_empty()

static func _read_variant_array(resource: Resource, property_name: String) -> Array:
	if resource == null:
		return []

	var value: Variant = resource.get(property_name)
	if not (value is Array):
		return []
	return (value as Array).duplicate()
