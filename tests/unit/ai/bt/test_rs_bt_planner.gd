extends GutTest

const RS_BT_PLANNER_PATH := "res://scripts/resources/ai/bt/rs_bt_planner.gd"
const RS_BT_PLANNER_ACTION_PATH := "res://scripts/resources/ai/bt/rs_bt_planner_action.gd"
const RS_WORLD_STATE_EFFECT_PATH := "res://scripts/resources/ai/bt/rs_world_state_effect.gd"
const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"

class TestStateEqualsCondition extends I_Condition:
	var key: StringName = &""
	var expected_value: Variant = null

	func _init(in_key: StringName, in_expected_value: Variant) -> void:
		key = in_key
		expected_value = in_expected_value

	func evaluate(context: Dictionary) -> float:
		return 1.0 if context.get(key) == expected_value else 0.0

class PlannerSearchStub extends RefCounted:
	var queued_plans: Array = []
	var call_count: int = 0
	var initial_states: Array[Dictionary] = []

	func _init(plans: Array = []) -> void:
		queued_plans = plans.duplicate()

	func find_plan(initial_state: Dictionary, _goal: I_Condition, _pool: Array, _max_depth: int) -> Array:
		call_count += 1
		initial_states.append(initial_state.duplicate(true))
		if queued_plans.is_empty():
			return []
		var plan_variant: Variant = queued_plans[0]
		queued_plans.remove_at(0)
		if plan_variant is Array:
			return (plan_variant as Array).duplicate()
		return []

class WorldStateBuilderStub extends RefCounted:
	var state: Dictionary = {}
	var call_count: int = 0

	func _init(initial_state: Dictionary = {}) -> void:
		state = initial_state.duplicate(true)

	func build(_entity_query: Variant = null) -> Dictionary:
		call_count += 1
		return state.duplicate(true)

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

func _status(name: String) -> int:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return -1
	var status_enum: Variant = node_script.get("Status")
	if not (status_enum is Dictionary):
		return -1
	return int((status_enum as Dictionary).get(name, -1))

func _new_status_node(status: int) -> Resource:
	var status_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if status_script == null:
		return null
	var node_variant: Variant = status_script.new(status)
	assert_not_null(node_variant, "Expected status-node helper to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

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

func _new_planner_action_with_child(
	action_id: StringName,
	child_status: int,
	effects: Array,
	cost: float = 1.0
) -> Dictionary:
	var action: Resource = _new_resource(RS_BT_PLANNER_ACTION_PATH)
	var child: Resource = _new_status_node(child_status)
	if action == null or child == null:
		return {}
	action.resource_name = String(action_id)
	action.set("cost", cost)
	action.set("child", child)
	action.set("effects", effects)
	return {&"action": action, &"child": child}

func _new_planner(
	goal: I_Condition,
	action_pool: Array,
	search_stub: PlannerSearchStub,
	world_state_builder: WorldStateBuilderStub,
	max_depth: int = 6
) -> Resource:
	var planner_script: Script = _load_script(RS_BT_PLANNER_PATH)
	if planner_script == null:
		return null
	var planner_variant: Variant = planner_script.new()
	assert_not_null(planner_variant, "Expected RS_BTPlanner.new() to succeed")
	if planner_variant == null:
		return null
	var planner: Resource = planner_variant as Resource
	planner.set("goal", goal)
	planner.set("action_pool", action_pool)
	planner.set("max_depth", max_depth)
	planner.set("planner_search", search_stub)
	planner.set("world_state_builder", world_state_builder)
	return planner

func _local_state(state_bag: Dictionary, planner: Resource) -> Dictionary:
	if planner == null:
		return {}
	var node_id_variant: Variant = planner.get("node_id")
	var node_id: int = int(node_id_variant)
	var local_state_variant: Variant = state_bag.get(node_id, {})
	if local_state_variant is Dictionary:
		return local_state_variant as Dictionary
	return {}

func test_planner_script_exists_and_loads() -> void:
	var script: Script = _load_script(RS_BT_PLANNER_PATH)
	assert_not_null(script, "RS_BTPlanner script must exist and load")

func test_entry_plans_once_and_caches_debug_snapshot_in_state_bag() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var attack_data: Dictionary = _new_planner_action_with_child(
		&"attack",
		_status("RUNNING"),
		[_new_effect(&"goal_reached", "SET", true)],
		2.5
	)
	if attack_data.is_empty():
		return
	var attack_action: Resource = attack_data.get(&"action", null) as Resource
	var attack_child: Resource = attack_data.get(&"child", null) as Resource
	if attack_action == null or attack_child == null:
		return
	var search_stub := PlannerSearchStub.new([[attack_action]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [attack_action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status_tick_one: Variant = planner.call("tick", {&"entity_query": null}, state_bag)
	assert_eq(status_tick_one, _status("RUNNING"), "planned RUNNING action should return RUNNING")
	assert_eq(search_stub.call_count, 1, "search should run once on initial entry")
	var local_state: Dictionary = _local_state(state_bag, planner)
	assert_true(local_state.has(&"last_plan"), "planner should store last_plan in local state")
	assert_true(local_state.has(&"last_plan_cost"), "planner should store last_plan_cost in local state")
	assert_eq(local_state.get(&"last_plan"), [&"attack"], "last_plan should include selected action ids")
	assert_almost_eq(float(local_state.get(&"last_plan_cost", -1.0)), 2.5, 0.0001, "last_plan_cost should sum selected action costs")

	var status_tick_two: Variant = planner.call("tick", {&"entity_query": null}, state_bag)
	assert_eq(status_tick_two, _status("RUNNING"), "planner should re-enter cached running step")
	assert_eq(search_stub.call_count, 1, "running cached plan should not trigger replanning")
	assert_eq(attack_child.get("tick_count"), 2, "running child should be re-ticked on next frame")

func test_running_step_reenters_same_action_until_completion() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var first_data: Dictionary = _new_planner_action_with_child(&"first", _status("RUNNING"), [], 1.0)
	var second_data: Dictionary = _new_planner_action_with_child(&"second", _status("SUCCESS"), [], 1.0)
	if first_data.is_empty() or second_data.is_empty():
		return
	var first_action: Resource = first_data.get(&"action", null) as Resource
	var first_child: Resource = first_data.get(&"child", null) as Resource
	var second_action: Resource = second_data.get(&"action", null) as Resource
	var second_child: Resource = second_data.get(&"child", null) as Resource
	if first_action == null or first_child == null or second_action == null or second_child == null:
		return
	var search_stub := PlannerSearchStub.new([[first_action, second_action]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [first_action, second_action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status_one: Variant = planner.call("tick", {}, state_bag)
	var status_two: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status_one, _status("RUNNING"))
	assert_eq(status_two, _status("RUNNING"))
	assert_eq(first_child.get("tick_count"), 2, "planner should stay on the running step")
	assert_eq(second_child.get("tick_count"), 0, "planner should not advance while current step is RUNNING")

func test_step_success_advances_to_next_step() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var first_data: Dictionary = _new_planner_action_with_child(&"first", _status("RUNNING"), [], 1.0)
	var second_data: Dictionary = _new_planner_action_with_child(&"second", _status("RUNNING"), [], 1.0)
	if first_data.is_empty() or second_data.is_empty():
		return
	var first_action: Resource = first_data.get(&"action", null) as Resource
	var first_child: Resource = first_data.get(&"child", null) as Resource
	var second_action: Resource = second_data.get(&"action", null) as Resource
	var second_child: Resource = second_data.get(&"child", null) as Resource
	if first_action == null or first_child == null or second_action == null or second_child == null:
		return
	var search_stub := PlannerSearchStub.new([[first_action, second_action]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [first_action, second_action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status_one: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status_one, _status("RUNNING"), "first RUNNING step should keep planner running")
	first_child.set("fixed_status", _status("SUCCESS"))
	var status_two: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status_two, _status("RUNNING"), "planner should continue at next step after success")
	assert_eq(first_child.get("tick_count"), 2, "first step should have been re-entered once before advancing")
	assert_eq(second_child.get("tick_count"), 1, "planner should tick step i+1 after step i succeeds")

func test_final_step_success_and_goal_satisfied_returns_success() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var finish_data: Dictionary = _new_planner_action_with_child(
		&"finish",
		_status("RUNNING"),
		[_new_effect(&"goal_reached", "SET", true)],
		1.0
	)
	if finish_data.is_empty():
		return
	var finish_action: Resource = finish_data.get(&"action", null) as Resource
	var finish_child: Resource = finish_data.get(&"child", null) as Resource
	if finish_action == null or finish_child == null:
		return
	var search_stub := PlannerSearchStub.new([[finish_action]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [finish_action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status_one: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status_one, _status("RUNNING"))
	world_builder.state[&"goal_reached"] = true
	finish_child.set("fixed_status", _status("SUCCESS"))
	var status_two: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status_two, _status("SUCCESS"), "planner should succeed once final step succeeds and goal is satisfied")

func test_step_failure_attempts_one_replan_and_continues_if_found() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var fail_data: Dictionary = _new_planner_action_with_child(&"fail_step", _status("FAILURE"), [], 1.0)
	var recover_data: Dictionary = _new_planner_action_with_child(
		&"recover_step",
		_status("RUNNING"),
		[_new_effect(&"goal_reached", "SET", true)],
		1.0
	)
	if fail_data.is_empty() or recover_data.is_empty():
		return
	var fail_action: Resource = fail_data.get(&"action", null) as Resource
	var recover_action: Resource = recover_data.get(&"action", null) as Resource
	var recover_child: Resource = recover_data.get(&"child", null) as Resource
	if fail_action == null or recover_action == null or recover_child == null:
		return
	var search_stub := PlannerSearchStub.new([[fail_action], [recover_action]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [fail_action, recover_action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status_one: Variant = planner.call("tick", {}, state_bag)
	assert_eq(search_stub.call_count, 2, "planner should replan once after step failure")
	assert_eq(status_one, _status("RUNNING"), "planner should continue when replan finds a replacement path")
	var local_state: Dictionary = _local_state(state_bag, planner)
	assert_eq(local_state.get(&"last_plan"), [&"recover_step"], "debug plan snapshot should update after replanning")

	recover_child.set("fixed_status", _status("SUCCESS"))
	world_builder.state[&"goal_reached"] = true
	var status_two: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status_two, _status("SUCCESS"), "replanned step should be able to finish the planner")

func test_step_failure_with_failed_replan_returns_failure() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var fail_data: Dictionary = _new_planner_action_with_child(&"fail_step", _status("FAILURE"), [], 1.0)
	if fail_data.is_empty():
		return
	var fail_action: Resource = fail_data.get(&"action", null) as Resource
	if fail_action == null:
		return
	var search_stub := PlannerSearchStub.new([[fail_action], []])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [fail_action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status: Variant = planner.call("tick", {}, state_bag)
	assert_eq(search_stub.call_count, 2, "planner should make exactly one replan attempt after failure")
	assert_eq(status, _status("FAILURE"), "planner should fail when initial plan and one replan both fail")

func test_goal_already_satisfied_on_entry_returns_success_without_running_actions() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var action_data: Dictionary = _new_planner_action_with_child(
		&"should_not_run",
		_status("RUNNING"),
		[_new_effect(&"goal_reached", "SET", true)],
		1.0
	)
	if action_data.is_empty():
		return
	var action: Resource = action_data.get(&"action", null) as Resource
	var child: Resource = action_data.get(&"child", null) as Resource
	if action == null or child == null:
		return
	var search_stub := PlannerSearchStub.new([[action]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": true})
	var planner: Resource = _new_planner(goal, [action], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status, _status("SUCCESS"), "already-satisfied goals should short-circuit to SUCCESS")
	assert_eq(search_stub.call_count, 0, "already-satisfied goals should not invoke planner search")
	assert_eq(child.get("tick_count"), 0, "already-satisfied goals should not run any action")

func test_unsolvable_entry_returns_failure_and_pushes_error() -> void:
	var goal := TestStateEqualsCondition.new(&"goal_reached", true) as I_Condition
	var search_stub := PlannerSearchStub.new([[]])
	var world_builder := WorldStateBuilderStub.new({&"goal_reached": false})
	var planner: Resource = _new_planner(goal, [], search_stub, world_builder, 6)
	if planner == null:
		return

	var state_bag: Dictionary = {}
	var status: Variant = planner.call("tick", {}, state_bag)
	assert_eq(status, _status("FAILURE"), "unsolvable planner entry should fail")
	assert_push_error("no plan")
