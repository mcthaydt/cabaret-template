extends RefCounted
class_name U_AITaskRunner

const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

func tick(brain: C_AIBrainComponent, delta: float, context: Dictionary) -> StringName:
	if brain == null:
		return StringName()

	var queue: Array[RS_AIPrimitiveTask] = brain.current_task_queue
	if queue.is_empty():
		return StringName()

	var current_task_index: int = brain.current_task_index
	if current_task_index < 0 or current_task_index >= queue.size():
		return _finish_task_queue(brain, context)

	var task: RS_AIPrimitiveTask = queue[current_task_index]
	if task == null:
		return _advance_to_next_task(brain, current_task_index, queue.size(), context)

	var action: I_AIAction = task.action
	if action == null:
		return _advance_to_next_task(brain, current_task_index, queue.size(), context)

	var task_state: Dictionary = brain.task_state
	var action_started: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false))
	if not action_started:
		action.start(context, task_state)
		task_state[U_AI_TASK_STATE_KEYS.ACTION_STARTED] = true

	action.tick(context, task_state, maxf(delta, 0.0))
	brain.task_state = task_state

	var complete_variant: Variant = action.is_complete(context, task_state)
	var is_complete: bool = complete_variant is bool and complete_variant
	if not is_complete:
		return StringName()

	return _advance_to_next_task(brain, current_task_index, queue.size(), context)

func _advance_to_next_task(
	brain: C_AIBrainComponent,
	current_task_index: int,
	queue_size: int,
	context: Dictionary
) -> StringName:
	var next_task_index: int = current_task_index + 1
	brain.task_state = {}
	if next_task_index >= queue_size:
		return _finish_task_queue(brain, context)
	brain.current_task_index = next_task_index
	return StringName()

func _finish_task_queue(brain: C_AIBrainComponent, _context: Dictionary) -> StringName:
	var finished_goal_id: StringName = brain.get_active_goal_id()
	if finished_goal_id != StringName():
		var suspended: Dictionary = _read_suspended_state(brain)
		if suspended.has(finished_goal_id):
			suspended.erase(finished_goal_id)
			brain.suspended_goal_state = suspended

	brain.current_task_queue = []
	brain.current_task_index = 0
	brain.task_state = {}
	return finished_goal_id

func _read_suspended_state(brain: C_AIBrainComponent) -> Dictionary:
	return brain.suspended_goal_state
