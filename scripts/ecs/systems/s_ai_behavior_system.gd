@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIBehaviorSystem

const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_RULE := preload("res://scripts/resources/qb/rs_rule.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_RULE_SELECTOR := preload("res://scripts/utils/qb/u_rule_selector.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_HTN_PLANNER := preload("res://scripts/utils/ai/u_htn_planner.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

const MOBILE_EVALUATION_INTERVAL_MULTIPLIER: float = 2.0

const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const GOAL_DECISION_GROUP := StringName("ai_goal")

@export var state_store: I_StateStore = null
@export var debug_ai_logging: bool = false
@export var debug_ai_render_probe_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.5
@export var debug_entity_id: StringName = StringName("patrol_drone")

var _tracker: U_RuleStateTracker = RULE_STATE_TRACKER.new()
var _debug_log_cooldowns: Dictionary = {}
var _empty_query_log_cooldown_sec: float = 0.0
var _rule_pool: Dictionary = {}
var _goal_by_id_cache: Dictionary = {}  # resource_instance_id → Dictionary(StringName → Resource)
var _entity_stagger_index: int = 0
var _is_mobile: bool = false

func _init() -> void:
	execution_priority = -10
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()

func process_tick(delta: float) -> void:
	_tick_debug_log_cooldowns(delta)
	_tracker.tick_cooldowns(delta)

	var entities: Array = query_entities([BRAIN_COMPONENT_TYPE])
	if entities.is_empty():
		_debug_log_missing_brains()
		return

	# Use shared frame snapshot if available, otherwise resolve from store
	var redux_state: Dictionary = _get_frame_state_snapshot()
	if redux_state.is_empty():
		var store: I_StateStore = _resolve_store()
		if store != null:
			redux_state = store.get_state()

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

		var context: Dictionary = _build_entity_context(entity_query, brain, redux_state)
		active_context_keys.append(_context_key_for_context(context))
		_process_brain(brain, brain_settings, context, delta, _entity_stagger_index, entity_count)
		_debug_log_brain_state(context, brain)
		_entity_stagger_index += 1

	_tracker.cleanup_stale_contexts(active_context_keys)

func _process_brain(brain: C_AIBrainComponent, brain_settings: RS_AIBrainSettings, context: Dictionary, delta: float, entity_index: int = 0, entity_count: int = 1) -> void:
	if _should_evaluate_goals(brain, brain_settings, delta, entity_index, entity_count):
		var executing_goal_id: StringName = StringName()
		if not _is_task_queue_empty(brain):
			executing_goal_id = brain.get_active_goal_id()
		var selected_goal: RS_AIGoal = _select_goal(brain_settings, context, executing_goal_id)
		if selected_goal != null:
			var selected_goal_id: StringName = _read_goal_id(selected_goal)
			if selected_goal_id != StringName():
				var active_goal_id: StringName = brain.get_active_goal_id()
				var should_replan: bool = selected_goal_id != active_goal_id
				if not should_replan and _is_task_queue_empty(brain):
					should_replan = true
				if should_replan:
					_replan_for_goal(brain, selected_goal, context)

	_execute_current_task(brain, delta, context)

func _execute_current_task(brain: C_AIBrainComponent, delta: float, context: Dictionary) -> void:
	var queue: Array[RS_AIPrimitiveTask] = brain.current_task_queue
	if queue.is_empty():
		return

	var current_task_index: int = brain.current_task_index
	if current_task_index < 0 or current_task_index >= queue.size():
		_finish_task_queue(brain, context)
		return

	var task: RS_AIPrimitiveTask = queue[current_task_index]
	if task == null:
		_advance_to_next_task(brain, current_task_index, queue.size(), context)
		return

	var action_variant: Variant = task.action
	if action_variant == null or not (action_variant is I_AIAction):
		_advance_to_next_task(brain, current_task_index, queue.size(), context)
		return

	var task_state: Dictionary = brain.task_state

	var action_started: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false))
	var action: Variant = action_variant
	if not action_started:
		action.start(context, task_state)
		task_state[U_AI_TASK_STATE_KEYS.ACTION_STARTED] = true

	action.tick(context, task_state, maxf(delta, 0.0))
	brain.task_state = task_state

	var complete_variant: Variant = action.is_complete(context, task_state)
	var is_complete: bool = complete_variant is bool and complete_variant
	if not is_complete:
		return

	_advance_to_next_task(brain, current_task_index, queue.size(), context)

func _advance_to_next_task(brain: C_AIBrainComponent, current_task_index: int, queue_size: int, context: Dictionary) -> void:
	var next_task_index: int = current_task_index + 1
	brain.task_state = {}
	if next_task_index >= queue_size:
		_finish_task_queue(brain, context)
		return
	brain.current_task_index = next_task_index

func _finish_task_queue(brain: C_AIBrainComponent, context: Dictionary) -> void:
	var active_goal_id: StringName = brain.get_active_goal_id()
	if active_goal_id != StringName():
		var suspended: Dictionary = _read_suspended_state(brain)
		if suspended.has(active_goal_id):
			suspended.erase(active_goal_id)
			brain.suspended_goal_state = suspended
		_apply_deferred_goal_cooldown(active_goal_id, brain, context)

	brain.current_task_queue = []
	brain.current_task_index = 0
	brain.task_state = {}

func _apply_deferred_goal_cooldown(goal_id: StringName, brain: C_AIBrainComponent, context: Dictionary) -> void:
	var brain_settings: RS_AIBrainSettings = brain.get_brain_settings()
	if brain_settings == null:
		return
	var goals: Array[RS_AIGoal] = _read_goal_array(brain_settings)
	var goal: RS_AIGoal = _find_goal_by_id(goals, goal_id)
	if goal == null:
		return
	var rule: Resource = _build_rule_from_goal(goal)
	if rule == null:
		return
	_mark_goal_rule_fired(rule, context)

func _is_task_queue_empty(brain: C_AIBrainComponent) -> bool:
	return brain.current_task_queue.is_empty()

func _should_evaluate_goals(brain: C_AIBrainComponent, brain_settings: RS_AIBrainSettings, delta: float, entity_index: int = 0, entity_count: int = 1) -> bool:
	var evaluation_interval: float = maxf(brain_settings.evaluation_interval, 0.0)
	# Mobile: double the evaluation interval to reduce CPU cost of goal evaluation
	if _is_mobile:
		evaluation_interval *= MOBILE_EVALUATION_INTERVAL_MULTIPLIER
	var active_goal_id: StringName = brain.get_active_goal_id()

	if active_goal_id == StringName():
		# Stagger first evaluation: offset by entity index to prevent frame spikes
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

func _select_goal(brain_settings: RS_AIBrainSettings, context: Dictionary, executing_goal_id: StringName = StringName()) -> RS_AIGoal:
	var goals: Array[RS_AIGoal] = _read_goal_array(brain_settings)
	var default_goal_id: StringName = brain_settings.default_goal_id
	if goals.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var goal_rules: Array = []
	var goal_by_rule: Dictionary = {}
	for goal in goals:
		var goal_rule: Resource = _build_rule_from_goal(goal)
		if goal_rule == null:
			continue
		goal_rules.append(goal_rule)
		goal_by_rule[goal_rule] = goal

	if goal_rules.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var scored: Array[Dictionary] = U_RULE_SCORER.score_rules(goal_rules, context)
	if scored.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var gated: Array[Dictionary] = _apply_state_gates(goal_rules, scored, context, executing_goal_id)
	if gated.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var winners: Array[Dictionary] = U_RULE_SELECTOR.select_winners(gated)
	if winners.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var winning_entry_variant: Variant = winners[0]
	if not (winning_entry_variant is Dictionary):
		return _find_goal_by_id(goals, default_goal_id)
	var winning_entry: Dictionary = winning_entry_variant as Dictionary
	var winning_rule: Variant = winning_entry.get("rule", null)
	if goal_by_rule.has(winning_rule):
		return goal_by_rule.get(winning_rule) as Resource

	return _find_goal_by_id(goals, default_goal_id)

func _replan_for_goal(brain: C_AIBrainComponent, goal: RS_AIGoal, context: Dictionary) -> void:
	var goal_id: StringName = _read_goal_id(goal)
	_suspend_current_goal(brain)

	brain.active_goal_id = goal_id
	brain.task_state = {}

	var suspended: Dictionary = _read_suspended_state(brain)
	if suspended.has(goal_id):
		var saved: Dictionary = suspended.get(goal_id) as Dictionary
		var saved_queue: Variant = saved.get("task_queue", null)
		var saved_index: int = int(saved.get("task_index", 0))
		if saved_queue is Array and not (saved_queue as Array).is_empty():
			var restored_queue: Array[RS_AIPrimitiveTask] = []
			for task_variant in saved_queue:
				if task_variant is RS_AIPrimitiveTask:
					restored_queue.append(task_variant as RS_AIPrimitiveTask)
			brain.current_task_queue = restored_queue
			brain.current_task_index = saved_index
			suspended.erase(goal_id)
			brain.suspended_goal_state = suspended
			return

	brain.current_task_index = 0

	var planned_tasks: Array[RS_AIPrimitiveTask] = []
	if goal.root_task != null:
		var queue_variant: Variant = U_HTN_PLANNER.decompose(goal.root_task, context)
		if queue_variant is Array:
			for task_variant in queue_variant:
				if task_variant is RS_AIPrimitiveTask:
					planned_tasks.append(task_variant as RS_AIPrimitiveTask)

	brain.current_task_queue = planned_tasks

func _suspend_current_goal(brain: C_AIBrainComponent) -> void:
	var active_goal_id: StringName = brain.get_active_goal_id()
	if active_goal_id == StringName():
		return

	if brain.current_task_queue.is_empty():
		return

	var current_index: int = brain.current_task_index
	var suspended: Dictionary = _read_suspended_state(brain)
	suspended[active_goal_id] = {
		"task_queue": brain.current_task_queue,
		"task_index": current_index,
	}
	brain.suspended_goal_state = suspended

func _read_suspended_state(brain: C_AIBrainComponent) -> Dictionary:
	return brain.suspended_goal_state

func _build_rule_from_goal(goal: RS_AIGoal) -> Resource:
	if goal == null:
		return null

	var goal_id: StringName = _read_goal_id(goal)
	if goal_id == StringName():
		goal_id = StringName("__ai_goal_%d" % (goal as Object).get_instance_id())

	if _rule_pool.has(goal_id):
		var cached_rule: Resource = _rule_pool[goal_id]
		cached_rule.set("priority", _read_goal_priority(goal))
		cached_rule.set("conditions", _read_conditions(goal))
		cached_rule.set("score_threshold", goal.score_threshold)
		cached_rule.set("cooldown", goal.cooldown)
		cached_rule.set("one_shot", goal.one_shot)
		cached_rule.set("requires_rising_edge", goal.requires_rising_edge)
		return cached_rule

	var rule: Resource = RS_RULE.new()
	rule.set("rule_id", goal_id)
	rule.set("decision_group", GOAL_DECISION_GROUP)
	rule.set("priority", _read_goal_priority(goal))
	rule.set("conditions", _read_conditions(goal))
	rule.set("score_threshold", goal.score_threshold)
	rule.set("cooldown", goal.cooldown)
	rule.set("one_shot", goal.one_shot)
	rule.set("requires_rising_edge", goal.requires_rising_edge)

	_rule_pool[goal_id] = rule
	return rule

func _find_goal_by_id(goals: Array[RS_AIGoal], goal_id: StringName) -> RS_AIGoal:
	if goal_id == StringName():
		return null
	# Use cached lookup dictionary for O(1) resolution
	var cache_key: int = goals.hash()
	if not _goal_by_id_cache.has(cache_key):
		var new_lookup: Dictionary = {}
		for goal: RS_AIGoal in goals:
			if goal == null:
				continue
			new_lookup[_read_goal_id(goal)] = goal
		_goal_by_id_cache[cache_key] = new_lookup
	var lookup: Dictionary = _goal_by_id_cache[cache_key]
	if lookup.has(goal_id):
		return lookup[goal_id]
	return null

func _apply_state_gates(rules: Array, scored: Array[Dictionary], context: Dictionary, executing_goal_id: StringName = StringName()) -> Array[Dictionary]:
	var context_key: StringName = _context_key_for_context(context)

	var scored_by_rule: Dictionary = {}
	for result in scored:
		var rule_variant: Variant = result.get("rule", null)
		if rule_variant == null:
			continue
		scored_by_rule[rule_variant] = result

	var gated: Array[Dictionary] = []
	for rule_variant in rules:
		if not (rule_variant is RS_Rule):
			continue
		var rule: RS_Rule = rule_variant as RS_Rule

		var rule_id: StringName = _resolve_rule_id(rule)
		var is_executing: bool = executing_goal_id != StringName() and rule_id == executing_goal_id
		var requires_rising_edge: bool = rule.requires_rising_edge
		var is_passing_now: bool = scored_by_rule.has(rule)
		var has_rising_edge: bool = true
		if requires_rising_edge:
			has_rising_edge = _tracker.check_rising_edge(rule_id, context_key, is_passing_now)

		if not is_passing_now:
			continue
		if not is_executing:
			if _tracker.is_one_shot_spent(rule_id, context_key):
				continue
			if _tracker.is_on_cooldown(rule_id, context_key):
				continue
			if requires_rising_edge and not has_rising_edge:
				continue

		var result_variant: Variant = scored_by_rule.get(rule, null)
		if result_variant is Dictionary:
			gated.append(result_variant as Dictionary)

	return gated

func _mark_goal_rule_fired(rule_variant: Variant, context: Dictionary) -> void:
	if not (rule_variant is RS_Rule):
		return
	var rule: RS_Rule = rule_variant as RS_Rule

	var context_key: StringName = _context_key_for_context(context)
	var rule_id: StringName = _resolve_rule_id(rule)
	var cooldown: float = maxf(rule.cooldown, 0.0)
	_tracker.mark_fired(rule_id, context_key, cooldown)
	if rule.one_shot:
		_tracker.mark_one_shot_spent(rule_id, context_key)

func _build_entity_context(
	entity_query: Object,
	brain: C_AIBrainComponent,
	redux_state: Dictionary,
) -> Dictionary:
	var context: Dictionary = {
		"brain_component": brain,
		"redux_state": redux_state,
	}
	context["state"] = context["redux_state"]
	var store: I_StateStore = _resolve_store()
	if store != null:
		context["state_store"] = store

	var entity_variant: Variant = entity_query.get("entity")
	var manager: I_ECSManager = get_manager()
	if entity_variant is Node:
		var entity: Node = entity_variant as Node
		context["entity"] = entity
		context["entity_id"] = U_ECS_UTILS.get_entity_id(entity)

		var components: Dictionary = {}
		if manager != null:
			components = manager.get_components_for_entity_readonly(entity)
		if components.is_empty() and entity_query.has_method("get_all_components"):
			var query_components_variant: Variant = entity_query.call("get_all_components")
			if query_components_variant is Dictionary:
				components = query_components_variant as Dictionary
		if not components.is_empty():
			context["components"] = components
			context["component_data"] = components

	if not context.has("components"):
		var fallback_components: Dictionary = {
			BRAIN_COMPONENT_TYPE: brain,
		}
		context["components"] = fallback_components
		context["component_data"] = fallback_components

	return context

func _read_goal_array(brain_settings: RS_AIBrainSettings) -> Array[RS_AIGoal]:
	return brain_settings.goals

func _read_conditions(goal: RS_AIGoal) -> Array[Resource]:
	var conditions: Array[Resource] = []
	for condition_variant: I_Condition in goal.conditions:
		if condition_variant != null:
			conditions.append(condition_variant)
	return conditions

func _read_goal_id(goal: RS_AIGoal) -> StringName:
	if goal == null:
		return StringName()
	return goal.goal_id

func _read_goal_priority(goal: RS_AIGoal) -> int:
	if goal == null:
		return 0
	return goal.priority

func _resolve_store() -> I_StateStore:
	if state_store != null and is_instance_valid(state_store):
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _get_frame_state_snapshot() -> Dictionary:
	var manager := get_manager()
	if manager != null and manager.has_method("get_frame_state_snapshot"):
		return manager.get_frame_state_snapshot()
	var store: I_StateStore = _resolve_store()
	if store != null:
		return store.get_state()
	return {}

func _context_key_for_context(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = context.get("entity_id", StringName())
	if entity_id_variant is StringName:
		return entity_id_variant as StringName
	if entity_id_variant is String:
		var entity_id_text: String = entity_id_variant as String
		if entity_id_text.is_empty():
			return StringName()
		return StringName(entity_id_text)
	return StringName()

func _resolve_rule_id(rule_variant: Variant) -> StringName:
	var rule_id: StringName = StringName()
	if rule_variant is RS_Rule:
		rule_id = (rule_variant as RS_Rule).rule_id
	elif rule_variant is Object:
		var rule_id_variant: Variant = (rule_variant as Object).get("rule_id")
		if rule_id_variant is StringName:
			rule_id = rule_id_variant as StringName
		elif rule_id_variant is String:
			var rule_id_text: String = rule_id_variant as String
			if not rule_id_text.is_empty():
				rule_id = StringName(rule_id_text)
	if rule_id != StringName():
		return rule_id
	if rule_variant is Object:
		return StringName("__ai_goal_rule_%d" % (rule_variant as Object).get_instance_id())
	return StringName("__ai_goal_rule")

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
