extends GutTest

const U_AI_REPLANNER_PATH := "res://scripts/utils/ai/u_ai_replanner.gd"
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/rs_ai_goal.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const RS_AI_COMPOUND_TASK := preload("res://scripts/resources/ai/rs_ai_compound_task.gd")

func _load_replanner_script() -> Script:
	var script_variant: Variant = load(U_AI_REPLANNER_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_REPLANNER_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_brain(goals: Array[RS_AIGoal]) -> C_AIBrainComponent:
	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	autofree(brain)
	var settings: RS_AIBrainSettings = RS_AI_BRAIN_SETTINGS.new()
	settings.goals = goals
	brain.brain_settings = settings
	return brain

func _primitive(task_id: StringName) -> RS_AIPrimitiveTask:
	var task: RS_AIPrimitiveTask = RS_AI_PRIMITIVE_TASK.new()
	task.task_id = task_id
	return task

func _compound(task_id: StringName, subtasks: Array[RS_AITask]) -> RS_AICompoundTask:
	var task: RS_AICompoundTask = RS_AI_COMPOUND_TASK.new()
	task.task_id = task_id
	task.subtasks = subtasks
	return task

func _goal(goal_id: StringName, root_task: RS_AITask) -> RS_AIGoal:
	var goal: RS_AIGoal = RS_AI_GOAL.new()
	goal.goal_id = goal_id
	goal.root_task = root_task
	return goal

func test_replan_decomposes_root_task() -> void:
	var replanner_script: Script = _load_replanner_script()
	if replanner_script == null:
		return
	var replanner: Variant = replanner_script.new()
	var first: RS_AIPrimitiveTask = _primitive(&"first")
	var second: RS_AIPrimitiveTask = _primitive(&"second")
	var root: RS_AICompoundTask = _compound(&"root", [first, second])
	var patrol_goal: RS_AIGoal = _goal(&"patrol", root)
	var brain: C_AIBrainComponent = _new_brain([patrol_goal])

	var did_replan: bool = replanner.replan_for_goal(brain, patrol_goal, {})

	assert_true(did_replan)
	assert_eq(brain.active_goal_id, &"patrol")
	assert_eq(brain.current_task_queue.size(), 2)
	if brain.current_task_queue.size() != 2:
		return
	assert_eq(brain.current_task_queue[0].task_id, &"first")
	assert_eq(brain.current_task_queue[1].task_id, &"second")

func test_suspend_current_goal_saves_queue() -> void:
	var replanner_script: Script = _load_replanner_script()
	if replanner_script == null:
		return
	var replanner: Variant = replanner_script.new()
	var patrol_goal: RS_AIGoal = _goal(&"patrol", _primitive(&"patrol_task"))
	var investigate_goal: RS_AIGoal = _goal(&"investigate", _primitive(&"investigate_task"))
	var brain: C_AIBrainComponent = _new_brain([patrol_goal, investigate_goal])
	var patrol_queue: Array[RS_AIPrimitiveTask] = [_primitive(&"patrol_a"), _primitive(&"patrol_b")]
	brain.active_goal_id = &"patrol"
	brain.current_task_queue = patrol_queue
	brain.current_task_index = 1

	replanner.replan_for_goal(brain, investigate_goal, {})

	var suspended: Dictionary = brain.suspended_goal_state
	assert_true(suspended.has(&"patrol"))
	var patrol_state_variant: Variant = suspended.get(&"patrol", {})
	assert_true(patrol_state_variant is Dictionary)
	if not (patrol_state_variant is Dictionary):
		return
	var patrol_state: Dictionary = patrol_state_variant as Dictionary
	assert_eq(int(patrol_state.get("task_index", -1)), 1)
	var saved_queue_variant: Variant = patrol_state.get("task_queue", [])
	assert_true(saved_queue_variant is Array)
	if not (saved_queue_variant is Array):
		return
	assert_eq((saved_queue_variant as Array).size(), 2)

func test_restore_suspended_queue_on_reentry() -> void:
	var replanner_script: Script = _load_replanner_script()
	if replanner_script == null:
		return
	var replanner: Variant = replanner_script.new()
	var patrol_goal: RS_AIGoal = _goal(&"patrol", _primitive(&"patrol_task"))
	var investigate_goal: RS_AIGoal = _goal(&"investigate", _primitive(&"investigate_task"))
	var brain: C_AIBrainComponent = _new_brain([patrol_goal, investigate_goal])
	var patrol_first: RS_AIPrimitiveTask = _primitive(&"patrol_a")
	var patrol_second: RS_AIPrimitiveTask = _primitive(&"patrol_b")
	brain.active_goal_id = &"patrol"
	brain.current_task_queue = [patrol_first, patrol_second]
	brain.current_task_index = 1

	replanner.replan_for_goal(brain, investigate_goal, {})
	replanner.replan_for_goal(brain, patrol_goal, {})

	assert_eq(brain.active_goal_id, &"patrol")
	assert_eq(brain.current_task_index, 1)
	assert_eq(brain.current_task_queue.size(), 2)
	if brain.current_task_queue.size() != 2:
		return
	assert_eq(brain.current_task_queue[0], patrol_first)
	assert_eq(brain.current_task_queue[1], patrol_second)
	assert_false(brain.suspended_goal_state.has(&"patrol"))

func test_no_replan_when_same_goal_and_queue_nonempty() -> void:
	var replanner_script: Script = _load_replanner_script()
	if replanner_script == null:
		return
	var replanner: Variant = replanner_script.new()
	var patrol_goal: RS_AIGoal = _goal(&"patrol", _primitive(&"patrol_task"))
	var brain: C_AIBrainComponent = _new_brain([patrol_goal])
	var existing_task: RS_AIPrimitiveTask = _primitive(&"existing")
	brain.active_goal_id = &"patrol"
	brain.current_task_queue = [existing_task]
	brain.current_task_index = 0

	var did_replan: bool = replanner.replan_for_goal(brain, patrol_goal, {})

	assert_false(did_replan)
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	assert_eq(brain.current_task_queue[0], existing_task)
