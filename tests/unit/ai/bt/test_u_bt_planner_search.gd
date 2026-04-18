extends GutTest

const U_BT_PLANNER_SEARCH_PATH := "res://scripts/utils/ai/u_bt_planner_search.gd"
const RS_BT_PLANNER_ACTION_PATH := "res://scripts/resources/ai/bt/rs_bt_planner_action.gd"
const RS_WORLD_STATE_EFFECT_PATH := "res://scripts/resources/ai/bt/rs_world_state_effect.gd"

class TestStateEqualsCondition extends I_Condition:
	var key: StringName = &""
	var expected_value: Variant = null

	func _init(in_key: StringName, in_expected_value: Variant) -> void:
		key = in_key
		expected_value = in_expected_value

	func evaluate(context: Dictionary) -> float:
		return 1.0 if context.get(key) == expected_value else 0.0

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_resource(path: String) -> Resource:
	var script: Script = _load_script(path)
	if script == null:
		return null
	var instance_variant: Variant = script.new()
	assert_not_null(instance_variant, "Expected resource to instantiate: %s" % path)
	if instance_variant == null:
		return null
	return instance_variant as Resource

func _new_searcher() -> Object:
	var script: Script = _load_script(U_BT_PLANNER_SEARCH_PATH)
	if script == null:
		return null
	var instance_variant: Variant = script.new()
	assert_not_null(instance_variant, "Expected planner search utility to instantiate")
	if instance_variant == null:
		return null
	return instance_variant as Object

func _new_effect(key: StringName, op_name: String, value: Variant = null) -> Resource:
	var effect: Resource = _new_resource(RS_WORLD_STATE_EFFECT_PATH)
	if effect == null:
		return null
	var op_enum_variant: Variant = effect.get("Op")
	assert_true(op_enum_variant is Dictionary, "RS_WorldStateEffect should expose Op enum")
	if not (op_enum_variant is Dictionary):
		return null
	var op_enum: Dictionary = op_enum_variant as Dictionary
	effect.set("key", key)
	effect.set("op", int(op_enum.get(op_name, -1)))
	effect.set("value", value)
	return effect

func _new_planner_action(
	action_id: StringName,
	preconditions: Array[I_Condition],
	effects: Array,
	cost: float
) -> Resource:
	var action_resource: Resource = _new_resource(RS_BT_PLANNER_ACTION_PATH)
	if action_resource == null:
		return null
	action_resource.resource_name = String(action_id)
	action_resource.set("preconditions", preconditions)
	action_resource.set("effects", effects)
	action_resource.set("cost", cost)
	return action_resource

func _plan_names(plan: Array) -> Array[String]:
	var names: Array[String] = []
	for action_variant in plan:
		if action_variant is Resource:
			names.append((action_variant as Resource).resource_name)
	return names

func _plan_cost(plan: Array) -> float:
	var total_cost: float = 0.0
	for action_variant in plan:
		if action_variant is Object:
			total_cost += float((action_variant as Object).get("cost"))
	return total_cost

func _find_plan(searcher: Object, initial_state: Dictionary, goal: I_Condition, pool: Array, max_depth: int) -> Array:
	var plan_variant: Variant = searcher.call("find_plan", initial_state, goal, pool, max_depth)
	assert_true(plan_variant is Array, "find_plan should return an Array")
	if not (plan_variant is Array):
		return []
	return plan_variant as Array

func test_planner_search_script_exists_and_loads() -> void:
	var script: Script = _load_script(U_BT_PLANNER_SEARCH_PATH)
	assert_not_null(script, "U_BTPlannerSearch script must exist and load")

func test_goal_already_satisfied_returns_empty_plan_and_zero_cost() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var goal := TestStateEqualsCondition.new(&"hunger", 0) as I_Condition
	var plan: Array = _find_plan(searcher, {&"hunger": 0}, goal, [], 6)
	assert_eq(plan.size(), 0, "already-satisfied goals should return an empty plan")
	assert_almost_eq(_plan_cost(plan), 0.0, 0.0001, "empty plan should report zero total cost")

func test_single_action_plan_returns_that_action() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var preconditions: Array[I_Condition] = [TestStateEqualsCondition.new(&"hunger", 1) as I_Condition]
	var effects: Array = [_new_effect(&"hunger", "SET", 0)]
	if effects[0] == null:
		return
	var eat: Resource = _new_planner_action(&"eat", preconditions, effects, 1.0)
	if eat == null:
		return
	var goal := TestStateEqualsCondition.new(&"hunger", 0) as I_Condition
	var plan: Array = _find_plan(searcher, {&"hunger": 1}, goal, [eat], 6)
	assert_eq(_plan_names(plan), ["eat"], "single-step goals should return the single matching action")

func test_multistep_plan_respects_precondition_dependency_order() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var stalk: Resource = _new_planner_action(
		&"stalk",
		[] as Array[I_Condition],
		[_new_effect(&"has_line_of_sight", "SET", true)],
		1.0
	)
	var approach: Resource = _new_planner_action(
		&"approach",
		[TestStateEqualsCondition.new(&"has_line_of_sight", true) as I_Condition],
		[_new_effect(&"in_pounce_range", "SET", true)],
		1.0
	)
	if stalk == null or approach == null:
		return
	var goal := TestStateEqualsCondition.new(&"in_pounce_range", true) as I_Condition
	var initial_state: Dictionary = {&"has_line_of_sight": false, &"in_pounce_range": false}
	var plan: Array = _find_plan(searcher, initial_state, goal, [stalk, approach], 6)
	assert_eq(_plan_names(plan), ["stalk", "approach"], "planner should order dependent actions correctly")

func test_cost_optimal_plan_prefers_lower_total_cost_path() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var expensive_finish: Resource = _new_planner_action(
		&"expensive_finish",
		[] as Array[I_Condition],
		[_new_effect(&"goal_reached", "SET", true)],
		6.0
	)
	var prepare: Resource = _new_planner_action(
		&"prepare",
		[] as Array[I_Condition],
		[_new_effect(&"prepared", "SET", true)],
		1.0
	)
	var cheap_finish: Resource = _new_planner_action(
		&"cheap_finish",
		[TestStateEqualsCondition.new(&"prepared", true) as I_Condition],
		[_new_effect(&"goal_reached", "SET", true)],
		1.0
	)
	if expensive_finish == null or prepare == null or cheap_finish == null:
		return
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var plan: Array = _find_plan(searcher, {}, goal, [expensive_finish, prepare, cheap_finish], 6)
	assert_eq(_plan_names(plan), ["prepare", "cheap_finish"], "planner should select the lowest-cost valid path")
	assert_almost_eq(_plan_cost(plan), 2.0, 0.0001, "selected path should report the lower total cost")

func test_unsolvable_plan_returns_empty_and_reports_search_context() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var initial_state: Dictionary = {&"goal_reached": false}
	var pool: Array = []
	var plan: Array = _find_plan(searcher, initial_state, goal, pool, 4)
	assert_eq(plan.size(), 0, "unsolvable searches should return an empty plan")
	assert_push_error("pool size")
	assert_push_error("depth")
	assert_push_error("goal")
	assert_push_error("initial state")

func test_max_depth_rejects_plans_longer_than_cap() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var step_a: Resource = _new_planner_action(
		&"step_a",
		[] as Array[I_Condition],
		[_new_effect(&"a_done", "SET", true)],
		1.0
	)
	var step_b: Resource = _new_planner_action(
		&"step_b",
		[TestStateEqualsCondition.new(&"a_done", true) as I_Condition],
		[_new_effect(&"b_done", "SET", true)],
		1.0
	)
	var step_c: Resource = _new_planner_action(
		&"step_c",
		[TestStateEqualsCondition.new(&"b_done", true) as I_Condition],
		[_new_effect(&"goal_reached", "SET", true)],
		1.0
	)
	if step_a == null or step_b == null or step_c == null:
		return
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var plan: Array = _find_plan(searcher, {}, goal, [step_a, step_b, step_c], 2)
	assert_eq(plan.size(), 0, "plans longer than max_depth should be rejected")
	assert_push_error("depth")

func test_action_can_self_chain_only_when_effects_change_state() -> void:
	var searcher: Object = _new_searcher()
	if searcher == null:
		return
	var increment: Resource = _new_planner_action(
		&"increment",
		[] as Array[I_Condition],
		[_new_effect(&"counter", "ADD", 1)],
		1.0
	)
	if increment == null:
		return
	var goal := TestStateEqualsCondition.new(&"counter", 2) as I_Condition
	var plan: Array = _find_plan(searcher, {&"counter": 0}, goal, [increment], 6)
	assert_eq(_plan_names(plan), ["increment", "increment"], "state-changing actions should be allowed to self-chain")

	var no_change: Resource = _new_planner_action(
		&"no_change",
		[] as Array[I_Condition],
		[_new_effect(&"counter", "ADD", 0)],
		1.0
	)
	if no_change == null:
		return
	var no_change_plan: Array = _find_plan(searcher, {&"counter": 0}, goal, [no_change], 6)
	assert_eq(no_change_plan.size(), 0, "non-state-changing self-chains should be rejected")
