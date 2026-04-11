@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIBehaviorSystem

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_AI_GOAL_SELECTOR := preload("res://scripts/utils/ai/u_ai_goal_selector.gd")
const U_AI_TASK_RUNNER := preload("res://scripts/utils/ai/u_ai_task_runner.gd")
const U_AI_REPLANNER := preload("res://scripts/utils/ai/u_ai_replanner.gd")
const U_AI_CONTEXT_BUILDER := preload("res://scripts/utils/ai/u_ai_context_builder.gd")
const U_AI_RENDER_PROBE := preload("res://scripts/utils/debug/u_ai_render_probe.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

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
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()
var _rule_pool: Dictionary = {}
var _goal_by_id_cache: Dictionary = {}
var _is_mobile: bool = false

func _init() -> void:
	execution_priority = -10
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	_rule_pool = _goal_selector.get_rule_pool()
	_goal_by_id_cache = _goal_selector.get_goal_cache()

func process_tick(delta: float) -> void:
	_debug_log_throttle.tick(delta)
	_tracker.tick_cooldowns(delta)
	var entities: Array = query_entities([BRAIN_COMPONENT_TYPE])
	if entities.is_empty():
		_debug_log_missing_brains()
		return
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = _resolve_redux_state(store)
	var manager: I_ECSManager = get_manager()
	var active_context_keys: Array[StringName] = []
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
		var context: Dictionary = _context_builder.build(
			entity_query,
			brain,
			redux_state,
			store,
			manager
		)
		active_context_keys.append(_context_builder.context_key_for_context(context))
		_process_brain(brain, brain_settings, context, delta)
		_debug_log_brain_state(context, brain)
	_tracker.cleanup_stale_contexts(active_context_keys)

func _process_brain(
	brain: C_AIBrainComponent,
	brain_settings: RS_AIBrainSettings,
	context: Dictionary,
	delta: float
) -> void:
	if _should_evaluate_goals(brain, brain_settings, delta):
		var executing_goal_id: StringName = StringName()
		if not brain.current_task_queue.is_empty():
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
		_goal_selector.mark_goal_fired_by_id(brain_settings, finished_goal_id, context, _tracker)

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

func _resolve_store() -> I_StateStore:
	if state_store != null and is_instance_valid(state_store):
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _resolve_redux_state(store: I_StateStore) -> Dictionary:
	var manager: I_ECSManager = get_manager()
	var manager_state: Dictionary = {}
	if manager != null and manager.has_method("get_frame_state_snapshot"):
		manager_state = manager.get_frame_state_snapshot()
	if not manager_state.is_empty():
		return manager_state
	if store != null:
		return store.get_state()
	return manager_state

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	return _debug_log_throttle.consume_budget(entity_id, maxf(debug_log_interval_sec, 0.05))

func _debug_log_brain_state(context: Dictionary, brain: C_AIBrainComponent) -> void:
	var entity_id: StringName = _context_builder.context_key_for_context(context)
	if not _consume_debug_log_budget(entity_id):
		return

	var current_task: RS_AIPrimitiveTask = brain.get_current_task()
	var task_id: StringName = current_task.task_id if current_task != null else StringName()
	var queue_size: int = brain.current_task_queue.size()
	var task_state: Dictionary = brain.task_state
	var action_started: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false))
	var move_target_resolved: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_RESOLVED, false))
	var move_target_source: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_SOURCE, ""))

	var render_probe: String = ""
	if debug_ai_render_probe_logging:
		var movement_component: C_MovementComponent = null
		var components_variant: Variant = context.get("components", null)
		if components_variant is Dictionary:
			movement_component = (components_variant as Dictionary).get(MOVEMENT_COMPONENT_TYPE, null) as C_MovementComponent
		var entity: Node = context.get("entity", null) as Node
		render_probe = U_AI_RENDER_PROBE.build_probe_string(entity, null, movement_component)

	print(
		"S_AIBehaviorSystem[entity=%s] goal=%s queue_size=%d task_index=%d task_id=%s action_started=%s move_target_resolved=%s move_target_source=%s%s"
		% [
			str(entity_id),
			str(brain.get_active_goal_id()),
			queue_size,
			brain.current_task_index,
			str(task_id),
			str(action_started),
			str(move_target_resolved),
			move_target_source,
			render_probe,
		]
	)

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
