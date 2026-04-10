@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIBehaviorSystem

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_AI_GOAL_SELECTOR := preload("res://scripts/utils/ai/u_ai_goal_selector.gd")
const U_AI_TASK_RUNNER := preload("res://scripts/utils/ai/u_ai_task_runner.gd")
const U_AI_REPLANNER := preload("res://scripts/utils/ai/u_ai_replanner.gd")
const U_AI_CONTEXT_BUILDER := preload("res://scripts/utils/ai/u_ai_context_builder.gd")

const MOBILE_EVALUATION_INTERVAL_MULTIPLIER: float = 2.0

const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE

@export var state_store: I_StateStore = null
@export var debug_ai_logging: bool = false
@export var debug_ai_render_probe_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.5
@export var debug_entity_id: StringName = StringName("patrol_drone")

var _tracker: U_RuleStateTracker = RULE_STATE_TRACKER.new()
var _goal_selector: Variant = U_AI_GOAL_SELECTOR.new()
var _task_runner: Variant = U_AI_TASK_RUNNER.new()
var _replanner: Variant = U_AI_REPLANNER.new()
var _context_builder: Variant = U_AI_CONTEXT_BUILDER.new()

var _debug_log_cooldowns: Dictionary = {}
var _empty_query_log_cooldown_sec: float = 0.0
var _rule_pool: Dictionary = {}
var _goal_by_id_cache: Dictionary = {}
var _entity_stagger_index: int = 0
var _is_mobile: bool = false

func _init() -> void:
	execution_priority = -10
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	_rule_pool = _goal_selector.get_rule_pool()
	_goal_by_id_cache = _goal_selector.get_goal_cache()

func process_tick(delta: float) -> void:
	_tick_debug_log_cooldowns(delta)
	_tracker.tick_cooldowns(delta)

	var entities: Array = query_entities([BRAIN_COMPONENT_TYPE])
	if entities.is_empty():
		_debug_log_missing_brains()
		return

	var redux_state: Dictionary = _get_frame_state_snapshot()
	if redux_state.is_empty():
		var store: I_StateStore = _resolve_store()
		if store != null:
			redux_state = store.get_state()

	var manager: I_ECSManager = get_manager()
	var store_for_context: I_StateStore = _resolve_store()
	var entity_count: int = entities.size()
	_entity_stagger_index = 0

	var active_context_keys: Array = []
	for entity_query_variant in entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
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

		var context: Dictionary = _context_builder.build(
			entity_query,
			brain,
			redux_state,
			store_for_context,
			manager
		)
		active_context_keys.append(_context_builder.context_key_for_context(context))
		_process_brain(brain, brain_settings, context, delta, _entity_stagger_index, entity_count)
		_debug_log_brain_state(context, brain)
		_entity_stagger_index += 1

	_tracker.cleanup_stale_contexts(active_context_keys)

func _process_brain(
	brain: C_AIBrainComponent,
	brain_settings: RS_AIBrainSettings,
	context: Dictionary,
	delta: float,
	entity_index: int = 0,
	entity_count: int = 1
) -> void:
	if _should_evaluate_goals(brain, brain_settings, delta, entity_index, entity_count):
		var executing_goal_id: StringName = StringName()
		if not _is_task_queue_empty(brain):
			executing_goal_id = brain.get_active_goal_id()
		var selected_goal: RS_AIGoal = _goal_selector.select(
			brain_settings,
			context,
			_tracker,
			executing_goal_id
		)
		if selected_goal != null:
			_replanner.replan_for_goal(brain, selected_goal, context)

	var finished_goal_id: StringName = _task_runner.tick(brain, delta, context)
	if finished_goal_id != StringName():
		_apply_deferred_goal_cooldown(finished_goal_id, brain, context)

func _apply_deferred_goal_cooldown(goal_id: StringName, brain: C_AIBrainComponent, context: Dictionary) -> void:
	var brain_settings: RS_AIBrainSettings = brain.get_brain_settings()
	_goal_selector.mark_goal_fired_by_id(brain_settings, goal_id, context, _tracker)

func _is_task_queue_empty(brain: C_AIBrainComponent) -> bool:
	return brain.current_task_queue.is_empty()

func _should_evaluate_goals(
	brain: C_AIBrainComponent,
	brain_settings: RS_AIBrainSettings,
	delta: float,
	entity_index: int = 0,
	entity_count: int = 1
) -> bool:
	var evaluation_interval: float = maxf(brain_settings.evaluation_interval, 0.0)
	if _is_mobile:
		evaluation_interval *= MOBILE_EVALUATION_INTERVAL_MULTIPLIER
	var active_goal_id: StringName = brain.get_active_goal_id()

	if active_goal_id == StringName():
		var stagger_offset: float = 0.0
		if entity_count > 1:
			stagger_offset = (float(entity_index) / float(entity_count)) * evaluation_interval
		var current_timer: float = brain.evaluation_timer
		if current_timer == 0.0 and stagger_offset > 0.0:
			brain.evaluation_timer = -stagger_offset
		brain.evaluation_timer = 0.0
		return true

	if evaluation_interval <= 0.0:
		brain.evaluation_timer = 0.0
		return true

	var evaluation_timer: float = brain.evaluation_timer
	evaluation_timer += maxf(delta, 0.0)
	if evaluation_timer < evaluation_interval:
		brain.evaluation_timer = evaluation_timer
		return false

	brain.evaluation_timer = 0.0
	return true

func _resolve_store() -> I_StateStore:
	if state_store != null and is_instance_valid(state_store):
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _get_frame_state_snapshot() -> Dictionary:
	var manager: I_ECSManager = get_manager()
	if manager != null and manager.has_method("get_frame_state_snapshot"):
		return manager.get_frame_state_snapshot()
	var store: I_StateStore = _resolve_store()
	if store != null:
		return store.get_state()
	return {}

func _context_key_for_context(context: Dictionary) -> StringName:
	return _context_builder.context_key_for_context(context)

func _tick_debug_log_cooldowns(delta: float) -> void:
	_empty_query_log_cooldown_sec = maxf(_empty_query_log_cooldown_sec - maxf(delta, 0.0), 0.0)
	if _debug_log_cooldowns.is_empty():
		return
	var step: float = maxf(delta, 0.0)
	for key_variant in _debug_log_cooldowns.keys():
		var cooldown: float = float(_debug_log_cooldowns.get(key_variant, 0.0))
		cooldown = maxf(cooldown - step, 0.0)
		_debug_log_cooldowns[key_variant] = cooldown

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	var cooldown: float = float(_debug_log_cooldowns.get(entity_id, 0.0))
	if cooldown > 0.0:
		return false
	_debug_log_cooldowns[entity_id] = maxf(debug_log_interval_sec, 0.05)
	return true

func _debug_log_brain_state(context: Dictionary, brain: C_AIBrainComponent) -> void:
	var entity_id: StringName = _context_key_for_context(context)
	if not _consume_debug_log_budget(entity_id):
		return

	var active_goal_id: StringName = brain.get_active_goal_id()
	var current_task_index: int = brain.current_task_index
	var queue: Array[RS_AIPrimitiveTask] = brain.current_task_queue
	var queue_size: int = queue.size()
	var task_id: StringName = StringName()
	if current_task_index >= 0 and current_task_index < queue.size():
		var task: RS_AIPrimitiveTask = queue[current_task_index]
		if task != null:
			task_id = task.task_id

	var task_state: Dictionary = brain.task_state

	var has_move_target: bool = task_state.has(U_AI_TASK_STATE_KEYS.MOVE_TARGET)
	var move_target_variant: Variant = task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET, null)
	var move_target_resolved: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_RESOLVED, false))
	var move_target_source: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_SOURCE, ""))
	var move_target_reason: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_RESOLUTION_REASON, ""))
	var move_target_used_fallback: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_USED_FALLBACK, false))
	var move_target_requested_path: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH, ""))
	var move_target_context_entity_path: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_CONTEXT_ENTITY_PATH, ""))
	var move_target_context_owner_path: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_CONTEXT_OWNER_PATH, ""))
	var move_target_waypoint_index: int = int(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_WAYPOINT_INDEX, -1))
	var action_started: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false))
	var render_probe: String = ""
	if debug_ai_render_probe_logging:
		render_probe = _build_render_probe(context)

	print(
		"S_AIBehaviorSystem[entity=%s] goal=%s queue_size=%d task_index=%d task_id=%s action_started=%s move_target_resolved=%s has_move_target=%s move_target=%s source=%s reason=%s fallback=%s requested_path=%s context_entity=%s context_owner=%s waypoint_index=%d%s"
		% [
			str(entity_id),
			str(active_goal_id),
			queue_size,
			current_task_index,
			str(task_id),
			str(action_started),
			str(move_target_resolved),
			str(has_move_target),
			str(move_target_variant),
			move_target_source,
			move_target_reason,
			str(move_target_used_fallback),
			move_target_requested_path,
			move_target_context_entity_path,
			move_target_context_owner_path,
			move_target_waypoint_index,
			render_probe,
		]
	)

func _debug_log_missing_brains() -> void:
	if not debug_ai_logging:
		return
	if _empty_query_log_cooldown_sec > 0.0:
		return
	_empty_query_log_cooldown_sec = maxf(debug_log_interval_sec, 0.05)

	var manager: I_ECSManager = get_manager()
	var registered_brain_count: int = 0
	if manager != null:
		registered_brain_count = manager.get_components(BRAIN_COMPONENT_TYPE).size()

	print(
		"S_AIBehaviorSystem: query_entities([C_AIBrainComponent]) returned 0 entities; registered_brain_components=%d"
		% [registered_brain_count]
	)

func _build_render_probe(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	var entity_path: String = "<null>"
	if entity != null and is_instance_valid(entity):
		entity_path = str(entity.get_path())

	var body: CharacterBody3D = _resolve_body_from_context(context, entity)
	var body_visible: bool = false
	var body_visible_in_tree: bool = false
	var body_position: Vector3 = Vector3.ZERO
	if body != null and is_instance_valid(body):
		body_visible = body.visible
		body_visible_in_tree = body.is_visible_in_tree()
		body_position = body.global_position

	var visual_node: Node3D = _resolve_visual_node(entity, body)
	var visual_path: String = "<null>"
	var visual_type: String = "null"
	var visual_visible: bool = false
	var visual_visible_in_tree: bool = false
	var visual_transparency: Variant = "n/a"
	var visual_layers: Variant = "n/a"
	if visual_node != null and is_instance_valid(visual_node):
		visual_path = str(visual_node.get_path())
		visual_type = visual_node.get_class()
		visual_visible = visual_node.visible
		visual_visible_in_tree = visual_node.is_visible_in_tree()
		if visual_node is GeometryInstance3D:
			var geometry: GeometryInstance3D = visual_node as GeometryInstance3D
			visual_transparency = geometry.transparency
			visual_layers = geometry.layers

	return (
		" probe(entity_path=%s body_visible=%s body_visible_tree=%s body_pos=%s visual_path=%s visual_type=%s visual_visible=%s visual_visible_tree=%s visual_transparency=%s visual_layers=%s)"
		% [
			entity_path,
			str(body_visible),
			str(body_visible_in_tree),
			str(body_position),
			visual_path,
			visual_type,
			str(visual_visible),
			str(visual_visible_in_tree),
			str(visual_transparency),
			str(visual_layers),
		]
	)

func _resolve_body_from_context(context: Dictionary, entity: Node) -> CharacterBody3D:
	var components_variant: Variant = context.get("components", null)
	if components_variant is Dictionary:
		var components: Dictionary = components_variant as Dictionary
		var movement_component_variant: Variant = components.get(MOVEMENT_COMPONENT_TYPE, null)
		if movement_component_variant is C_MovementComponent:
			return (movement_component_variant as C_MovementComponent).get_character_body()
	return _find_character_body_recursive(entity)

func _resolve_visual_node(entity: Node, body: CharacterBody3D) -> Node3D:
	var search_root: Node = body
	if search_root == null:
		search_root = entity
	if search_root == null:
		return null

	var named_visual: Node = search_root.get_node_or_null("Visual")
	if named_visual is Node3D:
		return named_visual as Node3D
	return _find_first_geometry_recursive(search_root)

func _find_character_body_recursive(node: Node) -> CharacterBody3D:
	if node == null:
		return null
	if node is CharacterBody3D:
		return node as CharacterBody3D

	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: CharacterBody3D = _find_character_body_recursive(child)
		if found != null:
			return found
	return null

func _find_first_geometry_recursive(node: Node) -> Node3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	if node is CSGShape3D:
		return node as CSGShape3D

	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: Node3D = _find_first_geometry_recursive(child)
		if found != null:
			return found
	return null
