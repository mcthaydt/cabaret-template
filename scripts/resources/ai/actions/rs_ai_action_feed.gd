@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionFeed

const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_ENTITY_ACTIONS := preload("res://scripts/state/actions/u_entity_actions.gd")
const U_AI_ACTION_POSITION_RESOLVER := preload("res://scripts/utils/ai/u_ai_action_position_resolver.gd")

@export var consume_detected_target: bool = false
@export var consume_radius: float = 1.25

func start(context: Dictionary, task_state: Dictionary) -> void:
	var hunger_before: float = 0.0
	var needs_component: Object = _resolve_needs_component(context)
	if needs_component == null:
		push_error("RS_AIActionFeed.start: missing C_NeedsComponent in context.")
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return

	var settings_variant: Variant = needs_component.get("settings")
	if not (settings_variant is Resource):
		push_error("RS_AIActionFeed.start: C_NeedsComponent settings are missing.")
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return

	hunger_before = float(needs_component.get("hunger"))
	var settings: Resource = settings_variant as Resource
	var did_consume_target: bool = true
	var consume_reason: String = "consume_not_required"
	var consume_target_id: StringName = StringName("")
	if consume_detected_target:
		var consume_result: Dictionary = _consume_detected_target(context, task_state)
		did_consume_target = bool(consume_result.get("consumed", false))
		consume_reason = str(consume_result.get("reason", "consume_unknown"))
		consume_target_id = consume_result.get("target_entity_id", StringName("")) as StringName

	if (not consume_detected_target) or did_consume_target:
		var gain_on_feed: float = maxf(float(settings.get("gain_on_feed")), 0.0)
		var current_hunger: float = float(needs_component.get("hunger"))
		needs_component.set("hunger", clampf(current_hunger + gain_on_feed, 0.0, 1.0))
	var hunger_after: float = float(needs_component.get("hunger"))
	print("[ACTION] %s Feed consume_required=%s consumed=%s reason=%s target=%s hunger %.2f → %.2f" % [
		_resolve_entity_label(context),
		consume_detected_target,
		did_consume_target,
		consume_reason,
		consume_target_id,
		hunger_before,
		hunger_after
	])
	task_state[U_AITaskStateKeys.COMPLETED] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.COMPLETED, false))

func _resolve_needs_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var needs_variant: Variant = components.get(C_NEEDS_COMPONENT.COMPONENT_TYPE, null)
	if not (needs_variant is Object):
		return null
	return needs_variant as Object

func _consume_detected_target(context: Dictionary, task_state: Dictionary) -> Dictionary:
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	if detection == null:
		_print_feed_target_trace(context, task_state, StringName(""), null, false, "missing_detection_component")
		return {
			"consumed": false,
			"reason": "missing_detection_component",
			"target_entity_id": StringName(""),
		}

	var target_entity_id: StringName = StringName("")
	var task_target_variant: Variant = task_state.get(U_AITaskStateKeys.DETECTED_ENTITY_ID, StringName(""))
	if task_target_variant is StringName:
		target_entity_id = task_target_variant as StringName
	if target_entity_id == StringName("") and detection.pending_feed_entity_id != StringName(""):
		target_entity_id = detection.pending_feed_entity_id
	if target_entity_id == StringName(""):
		target_entity_id = detection.last_detected_player_entity_id
	if target_entity_id == StringName(""):
		_print_feed_target_trace(context, task_state, StringName(""), null, false, "missing_target_entity_id")
		return {
			"consumed": false,
			"reason": "missing_target_entity_id",
			"target_entity_id": StringName(""),
		}

	var target_entity: Node3D = _resolve_entity_by_id(context, target_entity_id)
	if target_entity == null or not is_instance_valid(target_entity):
		_print_feed_target_trace(context, task_state, target_entity_id, null, false, "target_entity_missing")
		return {
			"consumed": false,
			"reason": "target_entity_missing",
			"target_entity_id": target_entity_id,
		}

	if not _is_target_within_consume_radius(context, target_entity):
		_print_feed_target_trace(context, task_state, target_entity_id, target_entity, false, "target_out_of_consume_radius")
		return {
			"consumed": false,
			"reason": "target_out_of_consume_radius",
			"target_entity_id": target_entity_id,
		}

	var manager: I_ECSManager = _resolve_ecs_manager(context)
	if manager != null and manager.has_method("unregister_entity"):
		manager.call("unregister_entity", target_entity)

	var store: I_StateStore = context.get("state_store", null) as I_StateStore
	if store != null and is_instance_valid(store):
		store.dispatch(U_ENTITY_ACTIONS.remove_entity(target_entity_id))

	detection.is_player_in_range = false
	detection.last_detected_player_entity_id = StringName("")
	detection.pending_feed_entity_id = StringName("")
	_print_feed_target_trace(context, task_state, target_entity_id, target_entity, true, "consumed_target")
	task_state.erase(U_AITaskStateKeys.DETECTED_ENTITY_ID)
	target_entity.queue_free()
	return {
		"consumed": true,
		"reason": "consumed_target",
		"target_entity_id": target_entity_id,
	}

func _resolve_detection_component(context: Dictionary) -> C_DetectionComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_DETECTION_COMPONENT.COMPONENT_TYPE, null) as C_DetectionComponent

func _resolve_entity_by_id(context: Dictionary, entity_id: StringName) -> Node3D:
	var manager: I_ECSManager = _resolve_ecs_manager(context)
	if manager == null:
		return null
	var entity_variant: Variant = manager.get_entity_by_id(entity_id)
	return entity_variant as Node3D

func _resolve_ecs_manager(context: Dictionary) -> I_ECSManager:
	var manager: I_ECSManager = context.get("ecs_manager", null) as I_ECSManager
	if manager != null:
		return manager
	var entity: Node = context.get("entity", null) as Node
	if entity == null:
		return null
	return U_ECS_UTILS.get_manager(entity) as I_ECSManager

func _is_target_within_consume_radius(context: Dictionary, target_entity: Node3D) -> bool:
	var self_position_variant: Variant = _resolve_self_position(context)
	if not (self_position_variant is Vector3):
		return false
	var self_position: Vector3 = self_position_variant as Vector3
	var target_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(target_entity)
	if not (target_position_variant is Vector3):
		return false
	var target_position: Vector3 = target_position_variant as Vector3
	var delta_xz: Vector2 = Vector2(
		target_position.x - self_position.x,
		target_position.z - self_position.z
	)
	return delta_xz.length() <= maxf(consume_radius, 0.0)

func _resolve_self_position(context: Dictionary) -> Variant:
	return U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"

func _print_feed_target_trace(
	context: Dictionary,
	task_state: Dictionary,
	target_entity_id: StringName,
	target_entity: Node3D,
	consumed: bool,
	reason: String
) -> void:
	var detection: C_DetectionComponent = _resolve_detection_component(context)
	var task_locked_target_id: StringName = StringName("")
	var task_target_variant: Variant = task_state.get(U_AITaskStateKeys.DETECTED_ENTITY_ID, StringName(""))
	if task_target_variant is StringName:
		task_locked_target_id = task_target_variant as StringName
	var pending_target_id: StringName = StringName("")
	var live_target_id: StringName = StringName("")
	if detection != null:
		pending_target_id = detection.pending_feed_entity_id
		live_target_id = detection.last_detected_player_entity_id
	var target_tags: Array[StringName] = []
	if target_entity != null and is_instance_valid(target_entity):
		target_tags = U_ECS_UTILS.get_entity_tags(target_entity)
	var distance_xz: float = _resolve_xz_distance_to_target(context, target_entity)
	print("[ACTION_TRACE] %s FeedTarget locked=%s pending=%s live=%s resolved=%s tags=%s dist_xz=%.2f radius=%.2f consumed=%s reason=%s" % [
		_resolve_entity_label(context),
		task_locked_target_id,
		pending_target_id,
		live_target_id,
		target_entity_id,
		_format_tags_for_debug(target_tags),
		distance_xz,
		maxf(consume_radius, 0.0),
		consumed,
		reason,
	])

func _resolve_xz_distance_to_target(context: Dictionary, target_entity: Node3D) -> float:
	if target_entity == null or not is_instance_valid(target_entity):
		return INF
	var self_position_variant: Variant = _resolve_self_position(context)
	if not (self_position_variant is Vector3):
		return INF
	var self_position: Vector3 = self_position_variant as Vector3
	var target_position_variant: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_entity_position(target_entity)
	if not (target_position_variant is Vector3):
		return INF
	var target_position: Vector3 = target_position_variant as Vector3
	var delta_xz: Vector2 = Vector2(
		target_position.x - self_position.x,
		target_position.z - self_position.z
	)
	return delta_xz.length()

func _format_tags_for_debug(tags: Array[StringName]) -> String:
	var formatted: Array[String] = []
	for tag in tags:
		formatted.append(str(tag))
	return str(formatted)
