extends RefCounted
class_name U_HTNPlanner

const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_HTN_PLANNER_CONTEXT := preload("res://scripts/utils/ai/u_htn_planner_context.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd")
const RS_AI_COMPOUND_TASK := preload("res://scripts/resources/ai/tasks/rs_ai_compound_task.gd")
const RS_RULE := preload("res://scripts/resources/qb/rs_rule.gd")
const I_CONDITION := preload("res://scripts/interfaces/i_condition.gd")

static func decompose(task: Resource, context: Dictionary, max_depth: int = 20) -> Array[Resource]:
	if task == null:
		return []

	var safe_max_depth: int = maxi(max_depth, 0)
	var planner_context: Variant = U_HTN_PLANNER_CONTEXT.new(context, RS_RULE.new(), safe_max_depth)
	_decompose_recursive(task, planner_context)
	return planner_context.result

static func _decompose_recursive(
	task: Resource,
	planner_context: Variant
) -> void:
	if task == null:
		return
	if planner_context.depth > planner_context.max_depth:
		return

	if task is RS_AI_PRIMITIVE_TASK:
		planner_context.result.append(task)
		return

	if not (task is RS_AI_COMPOUND_TASK):
		return
	if planner_context.depth >= planner_context.max_depth:
		return

	var task_object: Object = task as Object
	if task_object == null:
		return
	var task_key: int = task_object.get_instance_id()
	if planner_context.recursion_stack.has(task_key):
		return

	planner_context.recursion_stack[task_key] = true
	var compound_task: RS_AICompoundTask = task as RS_AICompoundTask
	var subtasks: Array[RS_AITask] = []
	if compound_task != null:
		subtasks = compound_task.subtasks
	if subtasks.is_empty():
		planner_context.recursion_stack.erase(task_key)
		return

	var method_conditions: Array[I_Condition] = []
	if compound_task != null:
		method_conditions = compound_task.method_conditions
	if method_conditions.is_empty():
		for subtask: RS_AITask in subtasks:
			_decompose_subtask(subtask, planner_context)
		planner_context.recursion_stack.erase(task_key)
		return

	var branch_index: int = _select_branch_index(method_conditions, subtasks, planner_context)
	if branch_index >= 0 and branch_index < subtasks.size():
		_decompose_subtask(subtasks[branch_index], planner_context)

	planner_context.recursion_stack.erase(task_key)

static func _decompose_subtask(subtask: RS_AITask, planner_context: Variant) -> void:
	if subtask == null:
		return

	planner_context.depth += 1
	_decompose_recursive(subtask, planner_context)
	planner_context.depth -= 1

static func _select_branch_index(
	method_conditions: Array[I_Condition],
	subtasks: Array[RS_AITask],
	planner_context: Variant
) -> int:
	var slot_count: int = mini(method_conditions.size(), subtasks.size())
	if slot_count <= 0:
		return -1

	for index in range(slot_count):
		var subtask: RS_AITask = subtasks[index]
		var condition: I_Condition = method_conditions[index]
		if subtask == null or condition == null:
			continue
		if _method_condition_passes(condition, index, planner_context):
			return index

	return -1

static func _method_condition_passes(
	condition: I_Condition,
	method_index: int,
	planner_context: Variant
) -> bool:
	var method_rule: Resource = planner_context.reusable_rule
	method_rule.set("rule_id", StringName("__method_condition_%d" % method_index))
	var rule_conditions: Array[I_Condition] = []
	rule_conditions.append(condition)
	method_rule.set("conditions", rule_conditions)
	method_rule.set("score_threshold", 0.0)
	var scored_results: Array[Dictionary] = U_RULE_SCORER.score_rules([method_rule], planner_context.evaluation_context)
	return not scored_results.is_empty()
