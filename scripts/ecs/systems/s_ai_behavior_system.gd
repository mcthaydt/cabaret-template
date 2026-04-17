@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIBehaviorSystem

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_AI_GOAL_SELECTOR := preload("res://scripts/utils/ai/u_ai_goal_selector.gd")
const U_AI_TASK_RUNNER := preload("res://scripts/utils/ai/u_ai_task_runner.gd")
const U_AI_REPLANNER := preload("res://scripts/utils/ai/u_ai_replanner.gd")
const U_AI_CONTEXT_BUILDER := preload("res://scripts/utils/ai/u_ai_context_builder.gd")
const U_AI_BRAIN_SNAPSHOT_BUILDER := preload("res://scripts/ecs/systems/helpers/u_ai_brain_snapshot_builder.gd")
const U_AI_RENDER_PROBE := preload("res://scripts/utils/debug/u_ai_render_probe.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

const MOBILE_EVALUATION_INTERVAL_MULTIPLIER: float = 2.0
const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const DETECTION_COMPONENT_TYPE := C_DETECTION_COMPONENT.COMPONENT_TYPE
const NEEDS_COMPONENT_TYPE := C_NEEDS_COMPONENT.COMPONENT_TYPE
const PACK_DETECTION_COMPONENT_TYPE := StringName("C_DetectionComponent:pack")
const HUNT_GOAL_ID := StringName("hunt")
const HUNT_PACK_GOAL_ID := StringName("hunt_pack")

@export var state_store: I_StateStore = null
@export var debug_ai_logging: bool = false
var _state_store: I_StateStore = null
@export var debug_ai_render_probe_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.5
@export var debug_entity_id: StringName = StringName("patrol_drone")

var _tracker: U_RuleStateTracker = RULE_STATE_TRACKER.new()
var _goal_selector: U_AIGoalSelector = U_AI_GOAL_SELECTOR.new()
var _task_runner: U_AITaskRunner = U_AI_TASK_RUNNER.new()
var _replanner: U_AIReplanner = U_AI_REPLANNER.new()
var _context_builder: U_AIContextBuilder = U_AI_CONTEXT_BUILDER.new()
var _debug_log_throttle: U_DebugLogThrottle = U_DEBUG_LOG_THROTTLE.new()
var _rule_pool: Dictionary = {}
var _goal_by_id_cache: Dictionary = {}
var _is_mobile: bool = false

func _init() -> void:
	execution_priority = -10
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	_rule_pool = _goal_selector.get_rule_pool()
	_goal_by_id_cache = _goal_selector.get_goal_cache()

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.PRE_PHYSICS

func process_tick(delta: float) -> void:
	_debug_log_throttle.tick(delta)
	_tracker.tick_cooldowns(delta)
	var entities: Array = query_entities([BRAIN_COMPONENT_TYPE])
	if entities.is_empty():
		_debug_log_missing_brains()
		return
	var redux_state: Dictionary = get_frame_state_snapshot()
	var store: I_StateStore = _resolve_state_store()
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
		var snapshot: Dictionary = U_AI_BRAIN_SNAPSHOT_BUILDER.build(brain, context, _context_builder)
		brain.update_debug_snapshot(snapshot)
		_debug_log_brain_state(context, snapshot)
	_tracker.cleanup_stale_contexts(active_context_keys)

func _process_brain(
	brain: C_AIBrainComponent,
	brain_settings: RS_AIBrainSettings,
	context: Dictionary,
	delta: float
) -> void:
	var context_key: StringName = _context_builder.context_key_for_context(context)
	if _should_evaluate_goals(brain, brain_settings, delta):
		var active_goal_before: StringName = brain.get_active_goal_id()
		var queue_size_before: int = brain.current_task_queue.size()
		var executing_goal_id: StringName = StringName()
		if not brain.current_task_queue.is_empty():
			executing_goal_id = active_goal_before
		var selected_goal: RS_AIGoal = _goal_selector.select(
			brain_settings,
			context,
			_tracker,
			executing_goal_id
		)
		if selected_goal != null:
			var replan_applied: bool = _replanner.replan_for_goal(brain, selected_goal, context)
			if selected_goal.goal_id != active_goal_before:
				print("[BRAIN] %s goal: %s → %s%s" % [
					context_key, active_goal_before, selected_goal.goal_id,
					_build_goal_debug_suffix(brain, context)
				])
			elif replan_applied and queue_size_before == 0:
				print("[BRAIN] %s replan: reran %s (queue was empty)%s" % [
					context_key, selected_goal.goal_id,
					_build_goal_debug_suffix(brain, context)
				])

	var finished_goal_id: StringName = _task_runner.tick(brain, delta, context)
	if finished_goal_id != StringName():
		print("[BRAIN] %s goal completed: %s%s" % [
			context_key, finished_goal_id,
			_build_goal_debug_suffix(brain, context)
		])
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
	var entity_id: StringName = _context_builder.context_key_for_context(context)
	if not _consume_debug_log_budget(entity_id):
		return
	var render_probe: String = ""
	if debug_ai_render_probe_logging:
		var _mc: C_MovementComponent = null
		var _cv: Variant = context.get("components", null)
		if _cv is Dictionary: _mc = (_cv as Dictionary).get(MOVEMENT_COMPONENT_TYPE, null)
		render_probe = U_AI_RENDER_PROBE.build_probe_string(context.get("entity", null) as Node, null, _mc)
	print("S_AIBehaviorSystem[entity=%s] goal=%s queue=%d tidx=%d tid=%s started=%s resolved=%s src=%s susp=%s%s" % [
		entity_id, snapshot.get("goal_id", ""), int(snapshot.get("queue_size", 0)),
		int(snapshot.get("task_index", 0)), snapshot.get("task_id", ""),
		snapshot.get("action_started", false), snapshot.get("move_target_resolved", false),
		snapshot.get("move_target_source", ""), snapshot.get("suspended_goal_ids", []), render_probe])

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

func _build_goal_debug_suffix(brain: C_AIBrainComponent, context: Dictionary) -> String:
	var hunger_text: String = "?"
	var needs: C_NeedsComponent = _resolve_needs_component(context)
	if needs != null:
		hunger_text = "%.2f" % [needs.hunger]

	var primary_detection: C_DetectionComponent = _resolve_detection_component(context, DETECTION_COMPONENT_TYPE)
	var pack_detection: C_DetectionComponent = _resolve_detection_component(context, PACK_DETECTION_COMPONENT_TYPE)
	var prey_text: String = _format_detection_snapshot(primary_detection)
	var pack_text: String = _format_detection_snapshot(pack_detection)

	var context_key: StringName = _context_builder.context_key_for_context(context)
	var hunt_cooldown: float = _tracker.get_cooldown_remaining(HUNT_GOAL_ID, context_key)
	var pack_cooldown: float = _tracker.get_cooldown_remaining(HUNT_PACK_GOAL_ID, context_key)
	return " | hunger=%s prey=%s pack=%s q=%d cooldown[hunt]=%.2f cooldown[hunt_pack]=%.2f" % [
		hunger_text,
		prey_text,
		pack_text,
		brain.current_task_queue.size(),
		hunt_cooldown,
		pack_cooldown,
	]

func _resolve_detection_component(context: Dictionary, key: StringName) -> C_DetectionComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var detection_variant: Variant = components.get(key, null)
	if detection_variant is C_DetectionComponent:
		return detection_variant as C_DetectionComponent
	return null

func _resolve_needs_component(context: Dictionary) -> C_NeedsComponent:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var needs_variant: Variant = components.get(NEEDS_COMPONENT_TYPE, null)
	if needs_variant is C_NeedsComponent:
		return needs_variant as C_NeedsComponent
	return null

func _format_detection_snapshot(detection: C_DetectionComponent) -> String:
	if detection == null:
		return "missing"
	var detected_text: String = "in" if detection.is_player_in_range else "out"
	var target_id: String = str(detection.last_detected_player_entity_id)
	if target_id.is_empty():
		target_id = "-"
	return "%s:%s" % [detected_text, target_id]
