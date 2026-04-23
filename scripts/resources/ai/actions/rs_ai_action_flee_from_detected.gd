@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionFleeFromDetected

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_AI_ACTION_POSITION_RESOLVER := preload("res://scripts/utils/ai/u_ai_action_position_resolver.gd")
const HOME_ANCHOR_META_KEY := &"ai_home_anchor"
const TASK_PINNED_HOLD_ACTIVE := &"flee_pinned_hold_active"
const TASK_PINNED_HOLD_RETRY_SEC := &"flee_pinned_hold_retry_sec"
const MIN_PINNED_TARGET_DELTA_XZ: float = 0.1

@export var flee_distance: float = 6.0
@export var arrival_threshold: float = 0.5
@export var clamp_to_home_radius: bool = false
@export var home_radius: float = 10.0
@export_range(0.0, 2.0, 0.01, "or_greater") var pinned_hold_retry_sec: float = 0.25

func start(context: Dictionary, task_state: Dictionary) -> void:
	var self_entity: Node3D = context.get("entity", null) as Node3D
	if self_entity == null:
		push_error("RS_AIActionFleeFromDetected.start: missing entity in context.")
		_mark_completed(context, task_state, "missing_entity")
		return

	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection == null:
		push_error("RS_AIActionFleeFromDetected.start: missing C_DetectionComponent in context.")
		_mark_completed(context, task_state, "missing_detection_component")
		return

	var detected_entity_id: StringName = detection.last_detected_player_entity_id
	if detected_entity_id == StringName(""):
		push_error("RS_AIActionFleeFromDetected.start: stale detection (empty detected entity id).")
		_mark_completed(context, task_state, "stale_detection_empty_entity_id")
		return

	var detected_entity: Node3D = _resolve_detected_entity(context, detected_entity_id)
	if detected_entity == null:
		push_error("RS_AIActionFleeFromDetected.start: detected entity not found for id %s." % str(detected_entity_id))
		_mark_completed(context, task_state, "detected_entity_not_found")
		return

	var self_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)
	var detected_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(detected_entity)
	if not (self_position_variant is Vector3) or not (detected_position_variant is Vector3):
		_mark_completed(context, task_state, "missing_position")
		return
	var self_position: Vector3 = self_position_variant as Vector3
	var detected_position: Vector3 = detected_position_variant as Vector3
	var away_direction: Vector3 = (self_position - detected_position).normalized()
	var distance: float = maxf(flee_distance, 0.0)
	var target_position: Vector3 = self_position + away_direction * distance
	target_position = _clamp_target_to_home_anchor(self_entity, context, target_position)
	var resolved_arrival_threshold: float = maxf(arrival_threshold, 0.0)
	var has_meaningful_target: bool = _has_meaningful_target(self_position, target_position, resolved_arrival_threshold)
	task_state[TASK_PINNED_HOLD_ACTIVE] = false
	task_state[TASK_PINNED_HOLD_RETRY_SEC] = maxf(pinned_hold_retry_sec, 0.0)
	task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_arrival_threshold
	task_state[U_AITaskStateKeys.COMPLETED] = false
	if not has_meaningful_target and detection.is_player_in_range:
		_clear_move_target_component(context)
		task_state[TASK_PINNED_HOLD_ACTIVE] = true
		print("[ACTION] %s FleeFromDetected hold (pinned target)" % _resolve_entity_label(context))
		return
	_set_move_target_component_target(context, target_position, resolved_arrival_threshold)
	_write_resolution_debug(task_state, context, "flee_from_detected", "resolved_flee_target", false, true)
	print("[ACTION] %s FleeFromDetected → target (%.1f, %.1f, %.1f)" % [
		_resolve_entity_label(context), target_position.x, target_position.y, target_position.z])

func tick(context: Dictionary, task_state: Dictionary, _delta: float) -> void:
	if bool(task_state.get(U_AITaskStateKeys.COMPLETED, false)):
		return
	if bool(task_state.get(TASK_PINNED_HOLD_ACTIVE, false)):
		if _should_release_pinned_hold(context):
			_mark_completed(context, task_state, "pinned_hold_released")
			return
		var retry_after_sec: float = maxf(float(task_state.get(TASK_PINNED_HOLD_RETRY_SEC, 0.0)), 0.0)
		retry_after_sec -= maxf(_delta, 0.0)
		task_state[TASK_PINNED_HOLD_RETRY_SEC] = retry_after_sec
		if retry_after_sec > 0.0:
			return
		task_state[TASK_PINNED_HOLD_RETRY_SEC] = maxf(pinned_hold_retry_sec, 0.0)
		var repath_succeeded: bool = _refresh_flee_target(context, task_state)
		if repath_succeeded:
			task_state[TASK_PINNED_HOLD_ACTIVE] = false
		return
	_refresh_flee_target(context, task_state)

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	if bool(task_state.get(U_AITaskStateKeys.COMPLETED, false)):
		return true
	if bool(task_state.get(TASK_PINNED_HOLD_ACTIVE, false)):
		if _should_release_pinned_hold(context):
			_mark_completed(context, task_state, "pinned_hold_released")
			return true
		return false

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
	var target_position: Vector3 = target_variant as Vector3
	var current_position: Vector3 = current_position_variant as Vector3
	var offset_xz: Vector2 = Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	var arrived: bool = offset_xz.length() <= resolved_arrival_threshold
	if arrived:
		print("[ACTION] %s FleeFromDetected arrived" % _resolve_entity_label(context))
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.MOVE_TARGET_RESOLVED] = false
		task_state[U_AITaskStateKeys.COMPLETED] = true
	return arrived

func _mark_completed(context: Dictionary, task_state: Dictionary, reason: String) -> void:
	_clear_move_target_component(context)
	_write_resolution_debug(task_state, context, "flee_from_detected", reason, false, false)
	task_state.erase(U_AITaskStateKeys.MOVE_TARGET)
	task_state.erase(U_AITaskStateKeys.ARRIVAL_THRESHOLD)
	task_state.erase(TASK_PINNED_HOLD_ACTIVE)
	task_state.erase(TASK_PINNED_HOLD_RETRY_SEC)
	task_state[U_AITaskStateKeys.COMPLETED] = true

func _refresh_flee_target(context: Dictionary, task_state: Dictionary) -> bool:
	var self_entity: Node3D = context.get("entity", null) as Node3D
	if self_entity == null:
		return false
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection == null:
		return false
	if not detection.is_player_in_range:
		return false
	var detected_entity_id: StringName = detection.last_detected_player_entity_id
	if detected_entity_id == StringName(""):
		return false
	var detected_entity: Node3D = _resolve_detected_entity(context, detected_entity_id)
	if detected_entity == null:
		return false
	var self_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)
	var detected_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(detected_entity)
	if not (self_position_variant is Vector3) or not (detected_position_variant is Vector3):
		return false
	var self_position: Vector3 = self_position_variant as Vector3
	var detected_position: Vector3 = detected_position_variant as Vector3
	var away_direction: Vector3 = (self_position - detected_position).normalized()
	if away_direction.length_squared() < 0.001:
		return false
	var distance: float = maxf(flee_distance, 0.0)
	var target_position: Vector3 = self_position + away_direction * distance
	target_position = _clamp_target_to_home_anchor(self_entity, context, target_position)
	var resolved_arrival_threshold: float = maxf(arrival_threshold, 0.0)
	if not _has_meaningful_target(self_position, target_position, resolved_arrival_threshold):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
		task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_arrival_threshold
		return false
	_set_move_target_component_target(context, target_position, resolved_arrival_threshold)
	task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_arrival_threshold
	return true

func _has_meaningful_target(current_position: Vector3, target_position: Vector3, resolved_arrival_threshold: float) -> bool:
	var offset_xz: Vector2 = Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	var min_required_delta: float = maxf(
		resolved_arrival_threshold + MIN_PINNED_TARGET_DELTA_XZ,
		MIN_PINNED_TARGET_DELTA_XZ
	)
	return offset_xz.length() > min_required_delta

func _should_release_pinned_hold(context: Dictionary) -> bool:
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection == null:
		return true
	if not detection.is_player_in_range:
		return true
	var detected_entity_id: StringName = detection.last_detected_player_entity_id
	if detected_entity_id == StringName(""):
		return true
	var detected_entity: Node3D = _resolve_detected_entity(context, detected_entity_id)
	return detected_entity == null

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

func _clamp_target_to_home_anchor(entity: Node3D, context: Dictionary, target_position: Vector3) -> Vector3:
	if not clamp_to_home_radius:
		return target_position
	var max_home_radius: float = maxf(home_radius, 0.0)
	if max_home_radius <= 0.0:
		return target_position
	var home_anchor: Vector3 = _resolve_home_anchor(entity, context)
	var offset_xz := Vector2(target_position.x - home_anchor.x, target_position.z - home_anchor.z)
	if offset_xz.length() <= max_home_radius:
		return target_position
	var clamped_xz: Vector2 = offset_xz.normalized() * max_home_radius
	return Vector3(home_anchor.x + clamped_xz.x, target_position.y, home_anchor.z + clamped_xz.y)

func _resolve_home_anchor(entity: Node3D, context: Dictionary) -> Vector3:
	var stored_home_variant: Variant = null
	if entity.has_meta(HOME_ANCHOR_META_KEY):
		stored_home_variant = entity.get_meta(HOME_ANCHOR_META_KEY)
	if stored_home_variant is Vector3:
		return stored_home_variant as Vector3
	var home_position: Vector3 = entity.global_position
	var actor_position: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)
	if actor_position is Vector3:
		home_position = actor_position as Vector3
	entity.set_meta(HOME_ANCHOR_META_KEY, home_position)
	return home_position

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
