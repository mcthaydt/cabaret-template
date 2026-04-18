@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_AIBrainComponent

const COMPONENT_TYPE := StringName("C_AIBrainComponent")
const SNAPSHOT_KEY_LAST_PLAN := &"last_plan"
const SNAPSHOT_KEY_LAST_PLAN_COST := &"last_plan_cost"
@export var brain_settings: RS_AIBrainSettings = null

var _current_task_queue: Array[RS_AIPrimitiveTask] = []

var active_goal_id: StringName = StringName("")
var current_task_queue: Array[RS_AIPrimitiveTask] = []:
	get:
		return _current_task_queue
	set(value):
		_current_task_queue = _coerce_task_queue(value)
var current_task_index: int = 0
var task_state: Dictionary = {}
var evaluation_timer: float = 0.0
var suspended_goal_state: Dictionary = {}
var _debug_snapshot: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if brain_settings == null:
		push_error("C_AIBrainComponent missing brain_settings; assign an RS_AIBrainSettings resource.")
		return false
	return true

func get_brain_settings() -> RS_AIBrainSettings:
	return brain_settings

func get_active_goal_id() -> StringName:
	return active_goal_id

func get_current_task() -> RS_AIPrimitiveTask:
	if current_task_index < 0 or current_task_index >= current_task_queue.size():
		return null
	return current_task_queue[current_task_index]

func _coerce_task_queue(value: Variant) -> Array[RS_AIPrimitiveTask]:
	var coerced: Array[RS_AIPrimitiveTask] = []
	if not (value is Array):
		return coerced
	for task_variant in value as Array:
		if task_variant is RS_AIPrimitiveTask:
			coerced.append(task_variant as RS_AIPrimitiveTask)
	return coerced

func update_debug_snapshot(snapshot: Dictionary) -> void:
	_debug_snapshot = snapshot.duplicate(true)

func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = _debug_snapshot.duplicate(true)
	var planner_debug: Dictionary = _extract_planner_debug(task_state)
	if planner_debug.has(SNAPSHOT_KEY_LAST_PLAN):
		snapshot[SNAPSHOT_KEY_LAST_PLAN] = _coerce_plan_steps(planner_debug.get(SNAPSHOT_KEY_LAST_PLAN, []))
	if planner_debug.has(SNAPSHOT_KEY_LAST_PLAN_COST):
		var cost_variant: Variant = planner_debug.get(SNAPSHOT_KEY_LAST_PLAN_COST, 0.0)
		if cost_variant is float or cost_variant is int:
			snapshot[SNAPSHOT_KEY_LAST_PLAN_COST] = float(cost_variant)
	return snapshot

func _extract_planner_debug(state_bag: Dictionary) -> Dictionary:
	var direct_debug: Dictionary = {}
	if state_bag.has(SNAPSHOT_KEY_LAST_PLAN) or state_bag.has(SNAPSHOT_KEY_LAST_PLAN_COST):
		direct_debug = state_bag
	var fallback_debug: Dictionary = {}
	for value in state_bag.values():
		if not (value is Dictionary):
			continue
		var local_state: Dictionary = value as Dictionary
		if local_state.has(SNAPSHOT_KEY_LAST_PLAN) or local_state.has(SNAPSHOT_KEY_LAST_PLAN_COST):
			fallback_debug = local_state
	var selected: Dictionary = direct_debug if not direct_debug.is_empty() else fallback_debug
	return selected.duplicate(true)

func _coerce_plan_steps(value: Variant) -> Array[StringName]:
	var plan_steps: Array[StringName] = []
	if not (value is Array):
		return plan_steps
	for step_variant in value as Array:
		var step_text: String = str(step_variant)
		if step_text.is_empty():
			continue
		plan_steps.append(StringName(step_text))
	return plan_steps
