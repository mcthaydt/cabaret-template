extends RefCounted
class_name U_AIDebugFormatter

static func build_goal_debug_suffix(
	brain: C_AIBrainComponent,
	context: Dictionary,
	context_key: StringName,
	tracker: U_RuleStateTracker,
	needs_component_type: StringName,
	detection_component_type: StringName,
	pack_detection_component_type: StringName,
	hunt_goal_id: StringName,
	hunt_pack_goal_id: StringName
) -> String:
	var hunger_text: String = "?"
	var needs: C_NeedsComponent = _resolve_needs_component(context, needs_component_type)
	if needs != null:
		hunger_text = "%.2f" % [needs.hunger]

	var primary_detection: C_DetectionComponent = _resolve_detection_component(context, detection_component_type)
	var pack_detection: C_DetectionComponent = _resolve_detection_component(context, pack_detection_component_type)
	var prey_text: String = _format_detection_snapshot(primary_detection)
	var pack_text: String = _format_detection_snapshot(pack_detection)

	var hunt_cooldown: float = tracker.get_cooldown_remaining(hunt_goal_id, context_key)
	var pack_cooldown: float = tracker.get_cooldown_remaining(hunt_pack_goal_id, context_key)
	return " | hunger=%s prey=%s pack=%s q=%d cooldown[hunt]=%.2f cooldown[hunt_pack]=%.2f" % [
		hunger_text,
		prey_text,
		pack_text,
		brain.current_task_queue.size(),
		hunt_cooldown,
		pack_cooldown,
	]

static func _resolve_detection_component(context: Dictionary, key: StringName) -> C_DetectionComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var detection_variant: Variant = components.get(key, null)
	if detection_variant is C_DetectionComponent:
		return detection_variant as C_DetectionComponent
	return null

static func _resolve_needs_component(context: Dictionary, needs_component_type: StringName) -> C_NeedsComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var needs_variant: Variant = components.get(needs_component_type, null)
	if needs_variant is C_NeedsComponent:
		return needs_variant as C_NeedsComponent
	return null

static func _format_detection_snapshot(detection: C_DetectionComponent) -> String:
	if detection == null:
		return "missing"
	var detected_text: String = "in" if detection.is_player_in_range else "out"
	var target_id: String = str(detection.last_detected_player_entity_id)
	if target_id.is_empty():
		target_id = "-"
	return "%s:%s" % [detected_text, target_id]
