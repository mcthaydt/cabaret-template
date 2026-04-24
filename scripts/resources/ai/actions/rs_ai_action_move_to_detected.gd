@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionMoveToDetected

const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/demo/ecs/components/c_move_target_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_AI_ACTION_POSITION_RESOLVER := preload("res://scripts/utils/ai/u_ai_action_position_resolver.gd")

@export var arrival_threshold: float = 0.5
@export var completion_radius_override: float = 0.0

func start(context: Dictionary, task_state: Dictionary) -> void:
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection == null:
		push_error("RS_AIActionMoveToDetected.start: missing C_DetectionComponent in context.")
		_mark_completed(context, task_state, "missing_detection_component")
		return

	var resolved_arrival_threshold: float = maxf(arrival_threshold, 0.0)
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_arrival_threshold
	task_state[U_AITaskStateKeys.COMPLETED] = false
	if not _refresh_target_from_detection(context, task_state, true):
		_mark_completed(context, task_state, "stale_detection")
		return

	var target_position_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	var target_position: Vector3 = target_position_variant as Vector3
	print("[ACTION] %s MoveToDetected → target (%.1f, %.1f, %.1f)" % [
		_resolve_entity_label(context),
		target_position.x,
		target_position.y,
		target_position.z,
	])

func tick(context: Dictionary, task_state: Dictionary, _delta: float) -> void:
	if bool(task_state.get(U_AITaskStateKeys.COMPLETED, false)):
		return
	_refresh_target_from_detection(context, task_state, false)

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	if bool(task_state.get(U_AITaskStateKeys.COMPLETED, false)):
		return true

	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	if not (target_variant is Vector3):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.MOVE_TARGET_RESOLVED] = false
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return true

	var current_position_variant: Variant = _resolve_current_position(context)
	if not (current_position_variant is Vector3):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.MOVE_TARGET_RESOLVED] = false
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return true

	var resolved_arrival_threshold: float = maxf(
		float(task_state.get(U_AITaskStateKeys.ARRIVAL_THRESHOLD, arrival_threshold)),
		0.0
	)
	var resolved_completion_radius: float = maxf(completion_radius_override, 0.0)
	var completion_radius: float = maxf(resolved_arrival_threshold, resolved_completion_radius)
	var target_position: Vector3 = target_variant as Vector3
	var current_position: Vector3 = current_position_variant as Vector3
	var offset_xz: Vector2 = Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	var arrived: bool = offset_xz.length() <= completion_radius
	if arrived:
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.MOVE_TARGET_RESOLVED] = false
		task_state[U_AITaskStateKeys.COMPLETED] = true
		print("[ACTION] %s MoveToDetected arrived" % _resolve_entity_label(context))
	return arrived

func _refresh_target_from_detection(
	context: Dictionary,
	task_state: Dictionary,
	log_errors: bool
) -> bool:
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection == null:
		if log_errors:
			push_error("RS_AIActionMoveToDetected: missing C_DetectionComponent in context.")
		return false

	var detected_entity_id: StringName = detection.last_detected_player_entity_id
	if detected_entity_id == StringName(""):
		if log_errors:
			push_error("RS_AIActionMoveToDetected: stale detection (empty detected entity id).")
		return false

	var detected_entity: Node3D = _resolve_detected_entity(context, detected_entity_id)
	if detected_entity == null:
		if log_errors:
			push_error("RS_AIActionMoveToDetected: detected entity not found for id %s." % str(detected_entity_id))
		return false

	var resolved_arrival_threshold: float = maxf(
		float(task_state.get(U_AITaskStateKeys.ARRIVAL_THRESHOLD, arrival_threshold)),
		0.0
	)
	var target_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(detected_entity)
	if not (target_position_variant is Vector3):
		if log_errors:
			push_error("RS_AIActionMoveToDetected: detected entity position unresolved for id %s." % str(detected_entity_id))
		return false
	var target_position: Vector3 = target_position_variant as Vector3
	_set_move_target_component_target(context, target_position, resolved_arrival_threshold)
	_write_resolution_debug(task_state, context, "detected_entity", "resolved_detected_entity", false, true)
	detection.pending_feed_entity_id = detected_entity_id
	task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
	task_state[U_AITaskStateKeys.DETECTED_ENTITY_ID] = detected_entity_id
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_arrival_threshold
	return true

func _mark_completed(context: Dictionary, task_state: Dictionary, reason: String) -> void:
	_clear_move_target_component(context)
	_write_resolution_debug(task_state, context, "detected_entity", reason, false, false)
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection != null:
		detection.pending_feed_entity_id = StringName("")
	task_state.erase(U_AITaskStateKeys.MOVE_TARGET)
	task_state.erase(U_AITaskStateKeys.DETECTED_ENTITY_ID)
	task_state.erase(U_AITaskStateKeys.ARRIVAL_THRESHOLD)
	task_state[U_AITaskStateKeys.COMPLETED] = true

func _resolve_detection_component(context: Dictionary) -> C_DetectionComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_DETECTION_COMPONENT.COMPONENT_TYPE, null) as C_DetectionComponent

func _resolve_detected_entity(context: Dictionary, entity_id: StringName) -> Node3D:
	var manager: I_ECSManager = context.get("ecs_manager", null) as I_ECSManager
	if manager == null:
		var entity: Node = context.get("entity", null) as Node
		if entity != null:
			manager = U_ECS_UTILS.get_manager(entity) as I_ECSManager
	if manager == null:
		return null
	return manager.get_entity_by_id(entity_id) as Node3D

func _resolve_current_position(context: Dictionary) -> Variant:
	return U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)

func _write_resolution_debug(
	task_state: Dictionary,
	context: Dictionary,
	source: String,
	reason: String,
	used_fallback: bool,
	resolved: bool
) -> void:
	task_state[U_AITaskStateKeys.MOVE_TARGET_SOURCE] = source
	task_state[U_AITaskStateKeys.MOVE_TARGET_RESOLUTION_REASON] = reason
	task_state[U_AITaskStateKeys.MOVE_TARGET_USED_FALLBACK] = used_fallback
	task_state[U_AITaskStateKeys.MOVE_TARGET_REQUESTED_NODE_PATH] = ""
	task_state[U_AITaskStateKeys.MOVE_TARGET_CONTEXT_ENTITY_PATH] = _resolve_node_debug_path(context.get("entity", null))
	task_state[U_AITaskStateKeys.MOVE_TARGET_CONTEXT_OWNER_PATH] = _resolve_node_debug_path(context.get("owner_node", null))
	task_state[U_AITaskStateKeys.MOVE_TARGET_WAYPOINT_INDEX] = -1
	task_state[U_AITaskStateKeys.MOVE_TARGET_RESOLVED] = resolved

func _resolve_node_debug_path(node_variant: Variant) -> String:
	if not (node_variant is Node):
		return ""
	var node: Node = node_variant as Node
	if node == null or not is_instance_valid(node):
		return ""
	return str(node.get_path())

func _set_move_target_component_target(
	context: Dictionary,
	target_position_value: Vector3,
	arrival_threshold_value: float
) -> bool:
	var move_target_component: Object = _resolve_move_target_component(context)
	if move_target_component == null:
		return false
	move_target_component.set("target_position", target_position_value)
	move_target_component.set("arrival_threshold", maxf(arrival_threshold_value, 0.0))
	move_target_component.set("is_active", true)
	return true

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
	if not (move_target_component_variant is Object):
		return null
	return move_target_component_variant as Object

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
