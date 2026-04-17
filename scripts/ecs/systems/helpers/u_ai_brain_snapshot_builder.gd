extends RefCounted
class_name U_AIBrainSnapshotBuilder

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")

static func build(brain: C_AIBrainComponent, context: Dictionary, context_builder: U_AIContextBuilder) -> Dictionary:
	var current_task: RS_AIPrimitiveTask = brain.get_current_task()
	var task_id: StringName = current_task.task_id if current_task != null else StringName()
	var task_state: Dictionary = brain.task_state

	var detection_in_range: bool = false
	var detection_radius: float = 0.0
	var detection_exit_radius: float = 0.0
	var hunger: float = 1.0
	var sated_threshold: float = 0.7
	var starving_threshold: float = 0.25

	var components_variant: Variant = context.get("components", null)
	if components_variant is Dictionary:
		var components: Dictionary = components_variant as Dictionary
		var detection_component: C_DetectionComponent = components.get(C_DETECTION_COMPONENT.COMPONENT_TYPE, null)
		if detection_component != null:
			detection_in_range = detection_component.is_player_in_range
			detection_radius = detection_component.detection_radius
			detection_exit_radius = detection_component.detection_exit_radius
		var needs_component: Object = components.get(C_NEEDS_COMPONENT.COMPONENT_TYPE, null) as Object
		if needs_component != null:
			hunger = clampf(float(needs_component.get("hunger")), 0.0, 1.0)
			var needs_settings: Resource = needs_component.get("settings") as Resource
			if needs_settings != null:
				sated_threshold = clampf(float(needs_settings.get("sated_threshold")), 0.0, 1.0)
				starving_threshold = clampf(float(needs_settings.get("starving_threshold")), 0.0, 1.0)

	return {
		"entity_id": context_builder.context_key_for_context(context),
		"is_player_in_range": detection_in_range,
		"detection_radius": detection_radius,
		"detection_exit_radius": detection_exit_radius,
		"hunger": hunger,
		"sated_threshold": sated_threshold,
		"starving_threshold": starving_threshold,
		"goal_id": brain.get_active_goal_id(),
		"queue_size": brain.current_task_queue.size(),
		"task_index": brain.current_task_index,
		"task_id": task_id,
		"action_started": bool(task_state.get(U_AITaskStateKeys.ACTION_STARTED, false)),
		"move_target_resolved": bool(task_state.get(U_AITaskStateKeys.MOVE_TARGET_RESOLVED, false)),
		"move_target_source": str(task_state.get(U_AITaskStateKeys.MOVE_TARGET_SOURCE, "")),
		"suspended_goal_ids": brain.suspended_goal_state.keys() if brain.suspended_goal_state is Dictionary else [],
	}
