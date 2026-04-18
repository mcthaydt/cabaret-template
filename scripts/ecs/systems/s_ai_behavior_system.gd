@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIBehaviorSystem

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_BT_RUNNER := preload("res://scripts/utils/bt/u_bt_runner.gd")
const RS_BT_NODE := preload("res://scripts/resources/bt/rs_bt_node.gd")
const RS_RULE_CONTEXT := preload("res://scripts/resources/ecs/rs_rule_context.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_AI_RENDER_PROBE := preload("res://scripts/utils/debug/u_ai_render_probe.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

const MOBILE_EVALUATION_INTERVAL_MULTIPLIER: float = 2.0
const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const DETECTION_COMPONENT_TYPE := C_DETECTION_COMPONENT.COMPONENT_TYPE
const ROOT_ID_FALLBACK_PREFIX := "bt_root_"
const ROOT_MISSING_SENTINEL := &"bt_root_missing"

@export var state_store: I_StateStore = null
@export var debug_ai_logging: bool = false
var _state_store: I_StateStore = null
@export var debug_ai_render_probe_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.5
@export var debug_entity_id: StringName = StringName("patrol_drone")

var _bt_runner: U_BTRunner = U_BT_RUNNER.new()
var _debug_log_throttle: U_DebugLogThrottle = U_DEBUG_LOG_THROTTLE.new()
var _is_mobile: bool = false

func _init() -> void:
	execution_priority = -10
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.PRE_PHYSICS

func process_tick(delta: float) -> void:
	_debug_log_throttle.tick(delta)
	var entities: Array = query_entities([BRAIN_COMPONENT_TYPE])
	if entities.is_empty():
		_debug_log_missing_brains()
		return
	var redux_state: Dictionary = get_frame_state_snapshot()
	var store: I_StateStore = _resolve_state_store()
	var manager: I_ECSManager = get_manager()
	for entity_query_variant in entities:
		if not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue

		var brain_variant: Variant = entity_query.call("get_component", BRAIN_COMPONENT_TYPE)
		if not (brain_variant is C_AIBrainComponent):
			continue
		var brain: C_AIBrainComponent = brain_variant as C_AIBrainComponent
		var brain_settings: RS_AIBrainSettings = brain.get_brain_settings()
		if brain_settings == null:
			continue
		var context: Dictionary = _build_context(entity_query, brain, redux_state, store, manager)
		var status: int = _process_brain(brain, brain_settings, context, delta)
		var snapshot: Dictionary = _build_debug_snapshot(brain, context, status)
		brain.update_debug_snapshot(snapshot)
		_debug_log_brain_state(context, snapshot)

func _build_context(
	entity_query: Object,
	brain: C_AIBrainComponent,
	redux_state: Dictionary,
	store: I_StateStore,
	manager: I_ECSManager
) -> Dictionary:
	var rule_context: RSRuleContext = RS_RULE_CONTEXT.new()
	rule_context.brain_component = brain
	rule_context.redux_state = redux_state

	if store != null and is_instance_valid(store):
		rule_context.state_store = store

	if entity_query == null:
		rule_context.components = {BRAIN_COMPONENT_TYPE: brain}
		return rule_context.to_dictionary()

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant is Node:
		var entity: Node = entity_variant as Node
		rule_context.entity = entity
		rule_context.entity_id = U_ECS_UTILS.get_entity_id(entity)

		var components: Dictionary = {}
		if manager != null:
			components = manager.get_components_for_entity_readonly(entity)
		if components.is_empty() and entity_query.has_method("get_all_components"):
			var query_components_variant: Variant = entity_query.call("get_all_components")
			if query_components_variant is Dictionary:
				components = query_components_variant as Dictionary
		if not components.is_empty():
			_inject_role_keyed_detection(components, entity, manager)
			rule_context.components = components
		else:
			rule_context.components = {BRAIN_COMPONENT_TYPE: brain}
	else:
		rule_context.components = {BRAIN_COMPONENT_TYPE: brain}

	return rule_context.to_dictionary()

func _inject_role_keyed_detection(components: Dictionary, entity: Node, manager: I_ECSManager) -> void:
	if manager == null:
		return
	var all_detections: Array = manager.get_components(DETECTION_COMPONENT_TYPE)
	if all_detections.size() <= 1:
		return
	for detection_variant in all_detections:
		if detection_variant == null or not (detection_variant is C_DetectionComponent):
			continue
		var detection: C_DetectionComponent = detection_variant as C_DetectionComponent
		if not is_instance_valid(detection):
			continue
		var detection_root: Node = U_ECS_UTILS.find_entity_root(detection)
		if detection_root != entity:
			continue
		var role: StringName = detection.detection_role
		if role == StringName("") or role == StringName("primary"):
			components[DETECTION_COMPONENT_TYPE] = detection
			continue
		var role_key: StringName = StringName(String(DETECTION_COMPONENT_TYPE) + ":" + String(role))
		components[role_key] = detection

func _process_brain(
	brain: C_AIBrainComponent,
	brain_settings: RS_AIBrainSettings,
	context: Dictionary,
	delta: float
) -> int:
	if not _should_evaluate_goals(brain, brain_settings, delta):
		return -1
	var root: RS_BTNode = brain_settings.root
	if root == null:
		if brain.active_goal_id != ROOT_MISSING_SENTINEL:
			push_error("S_AIBehaviorSystem: root is null for brain %s" % str(brain.name))
			brain.active_goal_id = ROOT_MISSING_SENTINEL
		return RS_BT_NODE.Status.FAILURE
	brain.active_goal_id = _resolve_root_id(root)
	return _bt_runner.tick(root, context, brain.bt_state_bag)

func _should_evaluate_goals(
	brain: C_AIBrainComponent,
	brain_settings: RS_AIBrainSettings,
	delta: float
) -> bool:
	var evaluation_interval: float = maxf(brain_settings.evaluation_interval, 0.0)
	if _is_mobile:
		evaluation_interval *= MOBILE_EVALUATION_INTERVAL_MULTIPLIER

	if brain.get_active_goal_id() == StringName() or evaluation_interval <= 0.0:
		brain.evaluation_timer = 0.0
		return true

	brain.evaluation_timer += maxf(delta, 0.0)
	if brain.evaluation_timer < evaluation_interval:
		return false
	brain.evaluation_timer = 0.0
	return true

func _resolve_root_id(root: RS_BTNode) -> StringName:
	if root == null:
		return StringName()
	var resource_name: String = root.resource_name.strip_edges()
	if not resource_name.is_empty():
		return StringName(resource_name)
	return StringName("%s%d" % [ROOT_ID_FALLBACK_PREFIX, root.node_id])

func _build_debug_snapshot(
	brain: C_AIBrainComponent,
	context: Dictionary,
	status: int
) -> Dictionary:
	var entity_id_variant: Variant = context.get(RSRuleContext.KEY_ENTITY_ID, StringName())
	var entity_id: StringName
	if entity_id_variant is StringName:
		entity_id = entity_id_variant as StringName
	elif entity_id_variant is String:
		entity_id = StringName(entity_id_variant as String)
	else:
		entity_id = StringName()
	return {
		&"entity_id": entity_id,
		&"goal_id": brain.get_active_goal_id(),
		&"active_path": _build_active_path(brain),
		&"bt_status": status,
		&"bt_state_keys": brain.bt_state_bag.size(),
	}

func _build_active_path(brain: C_AIBrainComponent) -> Array[String]:
	var path: Array[String] = []
	var active_id: StringName = brain.get_active_goal_id()
	if active_id != StringName():
		path.append(str(active_id))
	return path

func _resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self)
	return _state_store

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	return _debug_log_throttle.consume_budget(entity_id, maxf(debug_log_interval_sec, 0.05))

func _debug_log_brain_state(context: Dictionary, snapshot: Dictionary) -> void:
	var entity_id_variant: Variant = snapshot.get(&"entity_id", StringName())
	var entity_id: StringName = entity_id_variant if entity_id_variant is StringName else StringName(str(entity_id_variant))
	if not _consume_debug_log_budget(entity_id):
		return
	var render_probe: String = ""
	if debug_ai_render_probe_logging:
		var _mc: C_MovementComponent = null
		var _cv: Variant = context.get("components", null)
		if _cv is Dictionary: _mc = (_cv as Dictionary).get(MOVEMENT_COMPONENT_TYPE, null)
		render_probe = U_AI_RENDER_PROBE.build_probe_string(context.get("entity", null) as Node, null, _mc)
	print("S_AIBehaviorSystem[entity=%s] root=%s active_path=%s bt_keys=%d%s" % [
		entity_id,
		snapshot.get("goal_id", ""),
		snapshot.get("active_path", []),
		int(snapshot.get("bt_state_keys", 0)),
		render_probe,
	])

func _debug_log_missing_brains() -> void:
	if not debug_ai_logging:
		return
	if not _debug_log_throttle.consume_budget(&"ai_behavior/empty_query", maxf(debug_log_interval_sec, 0.05)):
		return

	var registered_brain_count: int = 0
	var manager: I_ECSManager = get_manager()
	if manager != null:
		registered_brain_count = manager.get_components(BRAIN_COMPONENT_TYPE).size()
	print(
		"S_AIBehaviorSystem: query_entities([C_AIBrainComponent]) returned 0 entities; registered_brain_components=%d"
		% [registered_brain_count]
	)
