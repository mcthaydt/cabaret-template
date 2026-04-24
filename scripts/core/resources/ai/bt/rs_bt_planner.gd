@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_composite.gd"
class_name RS_BTPlanner

const U_BT_PLANNER_SEARCH := preload("res://scripts/core/utils/ai/u_bt_planner_search.gd")
const U_AI_WORLD_STATE_BUILDER := preload("res://scripts/core/utils/ai/u_ai_world_state_builder.gd")
const U_BT_PLANNER_RUNTIME := preload("res://scripts/core/utils/ai/u_bt_planner_runtime.gd")
const STATE_KEY_PLAN := &"plan"
const STATE_KEY_PLAN_INDEX := &"plan_index"
const STATE_KEY_REPLAN_ATTEMPTED := &"replan_attempted"
const STATE_KEY_LAST_PLAN := &"last_plan"
const STATE_KEY_LAST_PLAN_COST := &"last_plan_cost"
const CONTEXT_KEY_ENTITY_QUERY := &"entity_query"

var _runtime: Object = U_BT_PLANNER_RUNTIME.new()
var _action_pool: Array[Object] = []
var _planner_search: Object = U_BT_PLANNER_SEARCH.new()
var _world_state_builder: Object = U_AI_WORLD_STATE_BUILDER.new()
@export var goal: I_Condition = null
@export var max_depth: int = 6
@export var action_pool: Array = []:
	get:
		return _action_pool
	set(value):
		_action_pool = _runtime.call("coerce_action_pool", value)
@export var planner_search: Variant = null:
	get:
		return _planner_search
	set(value):
		if value is Object and (value as Object).has_method("find_plan"):
			_planner_search = value as Object
			return
		_planner_search = U_BT_PLANNER_SEARCH.new()
@export var world_state_builder: Variant = null:
	get:
		return _world_state_builder
	set(value):
		if value is Object and (value as Object).has_method("build"):
			_world_state_builder = value as Object
			return
		_world_state_builder = U_AI_WORLD_STATE_BUILDER.new()

func tick(context: Dictionary, state_bag: Dictionary) -> Status:
	if goal == null:
		push_error("RS_BTPlanner.tick: goal is null")
		return Status.FAILURE
	var world_state: Dictionary = _runtime.call("build_world_state", _world_state_builder, context, CONTEXT_KEY_ENTITY_QUERY)
	if _runtime.call("goal_satisfied", goal, world_state):
		_clear_runtime_state(state_bag)
		return Status.SUCCESS
	var local_state: Dictionary = _get_local_state(state_bag)
	var plan: Array[Object] = _runtime.call("coerce_action_pool", local_state.get(STATE_KEY_PLAN, []))
	var plan_index: int = int(local_state.get(STATE_KEY_PLAN_INDEX, 0))
	var replan_attempted: bool = bool(local_state.get(STATE_KEY_REPLAN_ATTEMPTED, false))
	if plan.is_empty():
		plan = _request_plan(world_state, state_bag, local_state, true)
		if plan.is_empty():
			return Status.FAILURE
		plan_index = 0
		replan_attempted = false
	while plan_index < plan.size():
		var action: Object = plan[plan_index]
		if action == null:
			push_error("RS_BTPlanner.tick: planned action at index %d is null" % plan_index)
			return Status.FAILURE
		var status_variant: Variant = action.call("tick", context, state_bag)
		var status: int = int(status_variant)
		if status == Status.RUNNING:
			_set_local_state(state_bag, plan, plan_index, replan_attempted, local_state)
			return Status.RUNNING
		if status == Status.SUCCESS:
			world_state = _runtime.call("apply_action_effects", world_state, action)
			plan_index += 1
			continue
		if status == Status.FAILURE:
			if replan_attempted:
				_clear_runtime_state(state_bag)
				return Status.FAILURE
			var replanned: Array[Object] = _request_plan(world_state, state_bag, local_state, false)
			if replanned.is_empty():
				_clear_runtime_state(state_bag)
				return Status.FAILURE
			plan = replanned
			plan_index = 0
			replan_attempted = true
			continue
		push_error("RS_BTPlanner.tick: invalid action status %s" % str(status_variant))
		_clear_runtime_state(state_bag)
		return Status.FAILURE
	if _runtime.call("goal_satisfied", goal, world_state):
		_clear_runtime_state(state_bag)
		return Status.SUCCESS
	push_error("RS_BTPlanner.tick: plan completed but goal remains unsatisfied")
	_clear_runtime_state(state_bag)
	return Status.FAILURE

func _request_plan(world_state: Dictionary, state_bag: Dictionary, local_state: Dictionary, emit_no_plan_error: bool) -> Array[Object]:
	var searcher: Object = _planner_search if _planner_search != null else U_BT_PLANNER_SEARCH.new()
	var depth_cap: int = maxi(max_depth, 0)
	var plan_variant: Variant = searcher.call("find_plan", world_state, goal, _action_pool, depth_cap)
	if not (plan_variant is Array):
		push_error("RS_BTPlanner.tick: planner search returned non-array plan")
		return []
	var plan: Array[Object] = _runtime.call("coerce_action_pool", plan_variant)
	if plan.is_empty():
		if emit_no_plan_error:
			push_error("RS_BTPlanner.tick: no plan found")
		return []
	var debug_snapshot: Dictionary = _runtime.call("build_plan_debug_snapshot", plan)
	local_state[STATE_KEY_LAST_PLAN] = debug_snapshot.get(STATE_KEY_LAST_PLAN, [])
	local_state[STATE_KEY_LAST_PLAN_COST] = debug_snapshot.get(STATE_KEY_LAST_PLAN_COST, 0.0)
	_set_local_state(state_bag, plan, 0, false, local_state)
	return plan

func _set_local_state(state_bag: Dictionary, plan: Array[Object], plan_index: int, replan_attempted: bool, local_state: Dictionary) -> void:
	local_state[STATE_KEY_PLAN] = plan.duplicate()
	local_state[STATE_KEY_PLAN_INDEX] = max(plan_index, 0)
	local_state[STATE_KEY_REPLAN_ATTEMPTED] = replan_attempted
	state_bag[node_id] = local_state

func _clear_runtime_state(state_bag: Dictionary) -> void:
	var local_state: Dictionary = _get_local_state(state_bag)
	local_state.erase(STATE_KEY_PLAN)
	local_state.erase(STATE_KEY_PLAN_INDEX)
	local_state.erase(STATE_KEY_REPLAN_ATTEMPTED)
	if local_state.is_empty():
		state_bag.erase(node_id)
		return
	state_bag[node_id] = local_state

func _get_local_state(state_bag: Dictionary) -> Dictionary:
	var state_variant: Variant = state_bag.get(node_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {}
