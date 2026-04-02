extends BaseTest

const U_HTN_PLANNER_PATH := "res://scripts/utils/ai/u_htn_planner.gd"
const RS_AI_PRIMITIVE_TASK_PATH := "res://scripts/resources/ai/rs_ai_primitive_task.gd"
const RS_AI_COMPOUND_TASK_PATH := "res://scripts/resources/ai/rs_ai_compound_task.gd"

class ConstantScoreCondition extends I_Condition:
	var score_value: float = 1.0

	func _init(initial_score: float = 1.0) -> void:
		score_value = initial_score

	func evaluate(_context: Dictionary) -> float:
		return score_value

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _primitive(task_id: StringName) -> Resource:
	var primitive_task_script: Script = _load_script(RS_AI_PRIMITIVE_TASK_PATH)
	if primitive_task_script == null:
		return null
	var task: Resource = primitive_task_script.new()
	task.set("task_id", task_id)
	return task

func _compound(task_id: StringName, subtasks: Array[Resource], method_conditions: Array[Resource] = []) -> Resource:
	var compound_task_script: Script = _load_script(RS_AI_COMPOUND_TASK_PATH)
	if compound_task_script == null:
		return null
	var task: Resource = compound_task_script.new()
	task.set("task_id", task_id)
	task.set("subtasks", subtasks)
	task.set("method_conditions", method_conditions)
	return task

func _decompose(task: Resource, context: Dictionary = {}, max_depth: int = 20) -> Array:
	var planner_script: Script = _load_script(U_HTN_PLANNER_PATH)
	if planner_script == null:
		return []
	var results_variant: Variant = planner_script.call("decompose", task, context, max_depth)
	if results_variant is Array:
		return results_variant as Array
	return []

func test_decompose_single_primitive_returns_itself() -> void:
	var primitive: Resource = _primitive(StringName("idle"))
	if primitive == null:
		return

	var results: Array = _decompose(primitive)
	assert_eq(results.size(), 1)
	if results.size() != 1:
		return
	assert_eq(results[0], primitive)

func test_decompose_compound_flattens_subtasks() -> void:
	var first: Resource = _primitive(StringName("first"))
	var second: Resource = _primitive(StringName("second"))
	if first == null or second == null:
		return

	var subtasks: Array[Resource] = [first, second]
	var root: Resource = _compound(StringName("root"), subtasks)
	if root == null:
		return

	var results: Array = _decompose(root)
	assert_eq(results, [first, second])

func test_decompose_nested_compounds() -> void:
	var first: Resource = _primitive(StringName("first"))
	var second: Resource = _primitive(StringName("second"))
	var third: Resource = _primitive(StringName("third"))
	if first == null or second == null or third == null:
		return

	var nested_subtasks: Array[Resource] = [second, third]
	var nested: Resource = _compound(StringName("nested"), nested_subtasks)
	if nested == null:
		return

	var root_subtasks: Array[Resource] = [first, nested]
	var root: Resource = _compound(StringName("root"), root_subtasks)
	if root == null:
		return

	var results: Array = _decompose(root)
	assert_eq(results, [first, second, third])

func test_decompose_with_method_conditions_selects_first_passing() -> void:
	var first: Resource = _primitive(StringName("first"))
	var second: Resource = _primitive(StringName("second"))
	var third: Resource = _primitive(StringName("third"))
	if first == null or second == null or third == null:
		return

	var first_condition: Resource = ConstantScoreCondition.new(0.0)
	var second_condition: Resource = ConstantScoreCondition.new(1.0)
	var third_condition: Resource = ConstantScoreCondition.new(1.0)

	var subtasks: Array[Resource] = [first, second, third]
	var conditions: Array[Resource] = [first_condition, second_condition, third_condition]
	var root: Resource = _compound(StringName("root"), subtasks, conditions)
	if root == null:
		return

	var results: Array = _decompose(root)
	assert_eq(results, [second])

func test_decompose_cycle_detection() -> void:
	var first: Resource = _compound(StringName("first"), [])
	var second: Resource = _compound(StringName("second"), [])
	if first == null or second == null:
		return

	var first_subtasks: Array[Resource] = [second]
	var second_subtasks: Array[Resource] = [first]
	first.set("subtasks", first_subtasks)
	second.set("subtasks", second_subtasks)

	var results: Array = _decompose(first)
	assert_true(results.is_empty())

func test_decompose_empty_compound_returns_empty() -> void:
	var compound: Resource = _compound(StringName("empty"), [])
	if compound == null:
		return

	var results: Array = _decompose(compound)
	assert_true(results.is_empty())

func test_decompose_null_task_returns_empty() -> void:
	var results: Array = _decompose(null)
	assert_true(results.is_empty())

func test_max_depth_guard() -> void:
	var leaf: Resource = _primitive(StringName("leaf"))
	if leaf == null:
		return
	var middle_subtasks: Array[Resource] = [leaf]
	var middle: Resource = _compound(StringName("middle"), middle_subtasks)
	if middle == null:
		return
	var root_subtasks: Array[Resource] = [middle]
	var root: Resource = _compound(StringName("root"), root_subtasks)
	if root == null:
		return

	var results: Array = _decompose(root, {}, 1)
	assert_true(results.is_empty())
