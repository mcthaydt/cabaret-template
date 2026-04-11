extends GutTest

const U_AI_GOAL_SELECTOR_PATH := "res://scripts/utils/ai/u_ai_goal_selector.gd"
const RS_AI_GOAL := preload("res://scripts/resources/ai/goals/rs_ai_goal.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd")
const RS_CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")

func _load_selector_script() -> Script:
	var script_variant: Variant = load(U_AI_GOAL_SELECTOR_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_GOAL_SELECTOR_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_goal(
	goal_id: StringName,
	priority: int,
	score: float,
	options: Dictionary = {}
) -> RS_AIGoal:
	var goal: RS_AIGoal = RS_AI_GOAL.new()
	var condition: I_Condition = RS_CONDITION_CONSTANT.new()
	condition.set("score", score)
	goal.goal_id = goal_id
	goal.priority = priority
	goal.conditions = [condition]
	goal.root_task = _new_task(goal_id)
	goal.cooldown = float(options.get("cooldown", 0.0))
	goal.one_shot = bool(options.get("one_shot", false))
	goal.requires_rising_edge = bool(options.get("requires_rising_edge", false))
	return goal

func _new_task(task_id: StringName) -> RS_AIPrimitiveTask:
	var task: RS_AIPrimitiveTask = RS_AI_PRIMITIVE_TASK.new()
	task.task_id = task_id
	return task

func _new_brain_settings(
	goals: Array[RS_AIGoal],
	default_goal_id: StringName = StringName()
) -> RS_AIBrainSettings:
	var settings: RS_AIBrainSettings = RS_AI_BRAIN_SETTINGS.new()
	settings.goals = goals
	settings.default_goal_id = default_goal_id
	return settings

func _goal_id(goal: RS_AIGoal) -> StringName:
	if goal == null:
		return StringName()
	return goal.goal_id

func test_selects_highest_scoring_goal() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var low_goal: RS_AIGoal = _new_goal(&"low", 1, 0.4)
	var high_goal: RS_AIGoal = _new_goal(&"high", 1, 0.9)
	var settings: RS_AIBrainSettings = _new_brain_settings([low_goal, high_goal], &"low")

	var selected: RS_AIGoal = selector.select(settings, {"entity_id": &"npc"}, tracker)
	assert_eq(_goal_id(selected), &"high")

func test_ties_broken_by_priority() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var low_priority: RS_AIGoal = _new_goal(&"low_priority", 1, 0.8)
	var high_priority: RS_AIGoal = _new_goal(&"high_priority", 5, 0.8)
	var settings: RS_AIBrainSettings = _new_brain_settings([low_priority, high_priority], &"low_priority")

	var selected: RS_AIGoal = selector.select(settings, {"entity_id": &"npc"}, tracker)
	assert_eq(_goal_id(selected), &"high_priority")

func test_falls_back_to_default_goal() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var first_goal: RS_AIGoal = _new_goal(&"first", 1, 0.0)
	var second_goal: RS_AIGoal = _new_goal(&"second", 1, 0.0)
	var settings: RS_AIBrainSettings = _new_brain_settings([first_goal, second_goal], &"second")

	var selected: RS_AIGoal = selector.select(settings, {"entity_id": &"npc"}, tracker)
	assert_eq(_goal_id(selected), &"second")

func test_applies_cooldown_gate() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var high_goal: RS_AIGoal = _new_goal(&"high", 2, 1.0, {"cooldown": 1.0})
	var fallback_goal: RS_AIGoal = _new_goal(&"fallback", 1, 0.8)
	var settings: RS_AIBrainSettings = _new_brain_settings([high_goal, fallback_goal], &"fallback")
	var context: Dictionary = {"entity_id": &"npc"}

	selector.mark_goal_fired(high_goal, context, tracker)
	var selected: RS_AIGoal = selector.select(settings, context, tracker)
	assert_eq(_goal_id(selected), &"fallback")

func test_applies_one_shot_gate() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var one_shot_goal: RS_AIGoal = _new_goal(&"one_shot", 2, 1.0, {"one_shot": true})
	var fallback_goal: RS_AIGoal = _new_goal(&"fallback", 1, 0.8)
	var settings: RS_AIBrainSettings = _new_brain_settings([one_shot_goal, fallback_goal], &"fallback")
	var context: Dictionary = {"entity_id": &"npc"}

	selector.mark_goal_fired(one_shot_goal, context, tracker)
	var selected: RS_AIGoal = selector.select(settings, context, tracker)
	assert_eq(_goal_id(selected), &"fallback")

func test_applies_rising_edge_gate() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var rising_goal: RS_AIGoal = _new_goal(&"rising", 2, 1.0, {"requires_rising_edge": true})
	var steady_goal: RS_AIGoal = _new_goal(&"steady", 1, 0.8)
	var settings: RS_AIBrainSettings = _new_brain_settings([rising_goal, steady_goal], &"steady")
	var context: Dictionary = {"entity_id": &"npc"}

	var first_selected: RS_AIGoal = selector.select(settings, context, tracker)
	assert_eq(_goal_id(first_selected), &"rising")

	var second_selected: RS_AIGoal = selector.select(settings, context, tracker)
	assert_eq(_goal_id(second_selected), &"steady")

func test_executing_goal_bypasses_cooldown_gate() -> void:
	var selector_script: Script = _load_selector_script()
	if selector_script == null:
		return
	var selector: Variant = selector_script.new()
	var tracker: U_RuleStateTracker = U_RuleStateTracker.new()
	var high_goal: RS_AIGoal = _new_goal(&"high", 2, 1.0, {"cooldown": 1.0})
	var fallback_goal: RS_AIGoal = _new_goal(&"fallback", 1, 0.8)
	var settings: RS_AIBrainSettings = _new_brain_settings([high_goal, fallback_goal], &"fallback")
	var context: Dictionary = {"entity_id": &"npc"}

	selector.mark_goal_fired(high_goal, context, tracker)
	var selected: RS_AIGoal = selector.select(settings, context, tracker, &"high")
	assert_eq(_goal_id(selected), &"high")
