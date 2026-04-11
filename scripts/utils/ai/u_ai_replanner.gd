extends RefCounted
class_name U_AIReplanner

const U_HTN_PLANNER := preload("res://scripts/utils/ai/u_htn_planner.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")

func replan_for_goal(brain: C_AIBrainComponent, goal: RS_AIGoal, context: Dictionary) -> bool:
	if brain == null or goal == null:
		return false

	var goal_id: StringName = goal.goal_id
	if goal_id == brain.get_active_goal_id() and not brain.current_task_queue.is_empty():
		return false

	_clear_move_target_component(context)
	_suspend_current_goal(brain)

	brain.active_goal_id = goal_id
	brain.task_state = {}

	var suspended: Dictionary = _read_suspended_state(brain)
	if suspended.has(goal_id):
		var saved_variant: Variant = suspended.get(goal_id, null)
		if saved_variant is Dictionary:
			var saved: Dictionary = saved_variant as Dictionary
			var saved_queue_variant: Variant = saved.get("task_queue", null)
			var saved_index: int = int(saved.get("task_index", 0))
			if saved_queue_variant is Array and not (saved_queue_variant as Array).is_empty():
				var restored_queue: Array[RS_AIPrimitiveTask] = _coerce_primitive_queue(saved_queue_variant as Array)
				if not restored_queue.is_empty():
					brain.current_task_queue = restored_queue
					brain.current_task_index = clampi(saved_index, 0, restored_queue.size() - 1)
					suspended.erase(goal_id)
					brain.suspended_goal_state = suspended
					return true
		suspended.erase(goal_id)
		brain.suspended_goal_state = suspended

	brain.current_task_index = 0
	var planned_tasks: Array[RS_AIPrimitiveTask] = []
	if goal.root_task != null:
		var queue_variant: Variant = U_HTN_PLANNER.decompose(goal.root_task, context)
		if queue_variant is Array:
			planned_tasks = _coerce_primitive_queue(queue_variant as Array)

	brain.current_task_queue = planned_tasks
	return true

func _suspend_current_goal(brain: C_AIBrainComponent) -> void:
	var active_goal_id: StringName = brain.get_active_goal_id()
	if active_goal_id == StringName():
		return
	if brain.current_task_queue.is_empty():
		return

	var suspended: Dictionary = _read_suspended_state(brain)
	suspended[active_goal_id] = {
		"task_queue": brain.current_task_queue,
		"task_index": brain.current_task_index,
	}
	brain.suspended_goal_state = suspended

func _read_suspended_state(brain: C_AIBrainComponent) -> Dictionary:
	return brain.suspended_goal_state

func _coerce_primitive_queue(tasks: Array) -> Array[RS_AIPrimitiveTask]:
	var queue: Array[RS_AIPrimitiveTask] = []
	for task_variant in tasks:
		if task_variant is RS_AIPrimitiveTask:
			queue.append(task_variant as RS_AIPrimitiveTask)
	return queue

func _clear_move_target_component(context: Dictionary) -> void:
	var move_target_component: Object = _resolve_move_target_component(context)
	if move_target_component == null:
		return
	move_target_component.set("is_active", false)

func _resolve_move_target_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var move_target_component_variant: Variant = components.get(C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE, null)
	if move_target_component_variant == null or not (move_target_component_variant is Object):
		return null
	return move_target_component_variant as Object
