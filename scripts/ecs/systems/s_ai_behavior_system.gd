@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIBehaviorSystem

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const I_AI_ACTION := preload("res://scripts/interfaces/i_ai_action.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/rs_ai_goal.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const RS_RULE := preload("res://scripts/resources/qb/rs_rule.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_RULE_SELECTOR := preload("res://scripts/utils/qb/u_rule_selector.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_HTN_PLANNER := preload("res://scripts/utils/ai/u_htn_planner.gd")

const BRAIN_COMPONENT_TYPE := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
const GOAL_DECISION_GROUP := StringName("ai_goal")
const ACTION_STARTED_STATE_KEY := "action_started"

@export var state_store: I_StateStore = null

var _tracker: U_RuleStateTracker = RULE_STATE_TRACKER.new()

func process_tick(delta: float) -> void:
	_tracker.tick_cooldowns(delta)

	var entities: Array = query_entities([BRAIN_COMPONENT_TYPE])
	if entities.is_empty():
		return

	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = {}
	if store != null:
		redux_state = store.get_state()

	var active_context_keys: Array = []
	for entity_query_variant in entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue

		var brain_variant: Variant = entity_query.call("get_component", BRAIN_COMPONENT_TYPE)
		if brain_variant == null or not (brain_variant is C_AI_BRAIN_COMPONENT):
			continue
		var brain_settings_variant: Variant = brain_variant.get("brain_settings")
		if brain_settings_variant == null or not (brain_settings_variant is RS_AI_BRAIN_SETTINGS):
			continue

		var context: Dictionary = _build_entity_context(entity_query, brain_variant, redux_state, store)
		active_context_keys.append(_context_key_for_context(context))
		_process_brain(brain_variant, brain_settings_variant as Resource, context, delta)

	_tracker.cleanup_stale_contexts(active_context_keys)

func _process_brain(brain: Variant, brain_settings: Resource, context: Dictionary, delta: float) -> void:
	if _should_evaluate_goals(brain, brain_settings, delta):
		var selected_goal: Resource = _select_goal(brain_settings, context)
		if selected_goal != null:
			var selected_goal_id: StringName = _read_goal_id(selected_goal)
			if selected_goal_id != StringName():
				var active_goal_variant: Variant = _read_object_property(brain, "active_goal_id")
				var active_goal_id: StringName = _variant_to_string_name(active_goal_variant)
				if selected_goal_id != active_goal_id:
					_replan_for_goal(brain, selected_goal, context)

	_execute_current_task(brain, delta, context)

func _execute_current_task(brain: Variant, delta: float, context: Dictionary) -> void:
	var queue_variant: Variant = _read_object_property(brain, "current_task_queue")
	if not (queue_variant is Array):
		return
	var queue: Array = queue_variant as Array
	if queue.is_empty():
		return

	var current_task_index: int = _read_int_property(brain, "current_task_index", 0)
	if current_task_index < 0 or current_task_index >= queue.size():
		_finish_task_queue(brain)
		return

	var task_variant: Variant = queue[current_task_index]
	if not (task_variant is RS_AI_PRIMITIVE_TASK):
		return

	var task: Resource = task_variant as Resource
	var action_variant: Variant = task.get("action")
	if action_variant == null or not (action_variant is I_AI_ACTION):
		return

	var task_state_variant: Variant = _read_object_property(brain, "task_state")
	var task_state: Dictionary = {}
	if task_state_variant is Dictionary:
		task_state = task_state_variant as Dictionary

	var action_started: bool = bool(task_state.get(ACTION_STARTED_STATE_KEY, false))
	var action: Variant = action_variant
	if not action_started:
		action.start(context, task_state)
		task_state[ACTION_STARTED_STATE_KEY] = true

	action.tick(context, task_state, maxf(delta, 0.0))
	brain.set("task_state", task_state)

	var complete_variant: Variant = action.is_complete(context, task_state)
	var is_complete: bool = complete_variant is bool and complete_variant
	if not is_complete:
		return

	_advance_to_next_task(brain, current_task_index, queue.size())

func _advance_to_next_task(brain: Variant, current_task_index: int, queue_size: int) -> void:
	var next_task_index: int = current_task_index + 1
	brain.set("task_state", {})
	if next_task_index >= queue_size:
		_finish_task_queue(brain)
		return
	brain.set("current_task_index", next_task_index)

func _finish_task_queue(brain: Variant) -> void:
	var empty_queue: Array[Resource] = []
	brain.set("current_task_queue", empty_queue)
	brain.set("current_task_index", 0)
	brain.set("task_state", {})

func _should_evaluate_goals(brain: Variant, brain_settings: Resource, delta: float) -> bool:
	var evaluation_interval: float = maxf(_read_float_property(brain_settings, "evaluation_interval", 0.5), 0.0)
	var active_goal_variant: Variant = _read_object_property(brain, "active_goal_id")
	var active_goal_id: StringName = _variant_to_string_name(active_goal_variant)

	if active_goal_id == StringName():
		brain.set("evaluation_timer", 0.0)
		return true

	if evaluation_interval <= 0.0:
		brain.set("evaluation_timer", 0.0)
		return true

	var evaluation_timer: float = _read_float_property(brain, "evaluation_timer", 0.0)
	evaluation_timer += maxf(delta, 0.0)
	if evaluation_timer < evaluation_interval:
		brain.set("evaluation_timer", evaluation_timer)
		return false

	brain.set("evaluation_timer", 0.0)
	return true

func _select_goal(brain_settings: Resource, context: Dictionary) -> Resource:
	var goals: Array[Resource] = _read_goal_array(brain_settings)
	var default_goal_variant: Variant = _read_object_property(brain_settings, "default_goal_id")
	var default_goal_id: StringName = _variant_to_string_name(default_goal_variant)
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

	var gated: Array[Dictionary] = _apply_state_gates(goal_rules, scored, context)
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

func _replan_for_goal(brain: Variant, goal: Resource, context: Dictionary) -> void:
	var goal_id: StringName = _read_goal_id(goal)
	brain.set("active_goal_id", goal_id)
	brain.set("current_task_index", 0)
	brain.set("task_state", {})

	var root_task_variant: Variant = goal.get("root_task")
	var planned_tasks: Array[Resource] = []
	if root_task_variant is Resource:
		var queue_variant: Variant = U_HTN_PLANNER.decompose(root_task_variant, context)
		if queue_variant is Array:
			for task_variant in queue_variant:
				if task_variant is Resource:
					planned_tasks.append(task_variant as Resource)

	brain.set("current_task_queue", planned_tasks)

func _build_rule_from_goal(goal: Resource) -> Resource:
	if goal == null:
		return null

	var rule: Resource = RS_RULE.new()
	var goal_id: StringName = _read_goal_id(goal)
	if goal_id == StringName():
		goal_id = StringName("__ai_goal_%d" % (goal as Object).get_instance_id())

	rule.set("rule_id", goal_id)
	rule.set("decision_group", GOAL_DECISION_GROUP)
	rule.set("priority", _read_goal_priority(goal))
	rule.set("conditions", _read_conditions(goal))
	rule.set("score_threshold", _read_float_property(goal, "score_threshold", 0.0))
	rule.set("cooldown", _read_float_property(goal, "cooldown", 0.0))
	rule.set("one_shot", _read_bool_property(goal, "one_shot", false))
	rule.set("requires_rising_edge", _read_bool_property(goal, "requires_rising_edge", false))
	return rule

func _find_goal_by_id(goals: Array[Resource], goal_id: StringName) -> Resource:
	if goal_id == StringName():
		return null
	for goal in goals:
		if goal == null:
			continue
		if _read_goal_id(goal) == goal_id:
			return goal
	return null

func _apply_state_gates(rules: Array, scored: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var context_key: StringName = _context_key_for_context(context)

	var scored_by_rule: Dictionary = {}
	for result in scored:
		var rule_variant: Variant = result.get("rule", null)
		if rule_variant == null:
			continue
		scored_by_rule[rule_variant] = result

	var gated: Array[Dictionary] = []
	for rule_variant in rules:
		if rule_variant == null or not (rule_variant is Object):
			continue

		var rule_id: StringName = _resolve_rule_id(rule_variant)
		var requires_rising_edge: bool = _read_bool_property(rule_variant, "requires_rising_edge", false)
		var is_passing_now: bool = scored_by_rule.has(rule_variant)
		var has_rising_edge: bool = true
		if requires_rising_edge:
			has_rising_edge = _tracker.check_rising_edge(rule_id, context_key, is_passing_now)

		if not is_passing_now:
			continue
		if _tracker.is_one_shot_spent(rule_id):
			continue
		if _tracker.is_on_cooldown(rule_id, context_key):
			continue
		if requires_rising_edge and not has_rising_edge:
			continue

		var result_variant: Variant = scored_by_rule.get(rule_variant, null)
		if result_variant is Dictionary:
			gated.append(result_variant as Dictionary)

		var cooldown: float = maxf(_read_float_property(rule_variant, "cooldown", 0.0), 0.0)
		_tracker.mark_fired(rule_id, context_key, cooldown)
		if _read_bool_property(rule_variant, "one_shot", false):
			_tracker.mark_one_shot_spent(rule_id)

	return gated

func _build_entity_context(
	entity_query: Object,
	brain: Variant,
	redux_state: Dictionary,
	store: I_StateStore
) -> Dictionary:
	var context: Dictionary = {
		"brain_component": brain,
		"redux_state": redux_state.duplicate(true),
	}
	context["state"] = context["redux_state"]
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
			components = manager.get_components_for_entity(entity)
		if components.is_empty() and entity_query.has_method("get_all_components"):
			var query_components_variant: Variant = entity_query.call("get_all_components")
			if query_components_variant is Dictionary:
				components = (query_components_variant as Dictionary).duplicate(true)
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

func _read_goal_array(brain_settings: Resource) -> Array[Resource]:
	var goals_variant: Variant = brain_settings.get("goals")
	if not (goals_variant is Array):
		return []
	var goals: Array[Resource] = []
	for goal_variant in goals_variant:
		if goal_variant is Resource:
			goals.append(goal_variant as Resource)
	return goals

func _read_conditions(goal: Resource) -> Array[Resource]:
	var conditions_variant: Variant = goal.get("conditions")
	if not (conditions_variant is Array):
		return []
	var conditions: Array[Resource] = []
	for condition_variant in conditions_variant:
		if condition_variant is Resource:
			conditions.append(condition_variant as Resource)
	return conditions

func _read_goal_id(goal: Resource) -> StringName:
	if goal == null:
		return StringName()
	var goal_id_variant: Variant = _read_object_property(goal, "goal_id")
	return _variant_to_string_name(goal_id_variant)

func _read_goal_priority(goal: Resource) -> int:
	if goal == null:
		return 0
	var priority_variant: Variant = goal.get("priority")
	if priority_variant is int:
		return priority_variant
	if priority_variant is float:
		return int(priority_variant)
	return 0

func _resolve_store() -> I_StateStore:
	if state_store != null and is_instance_valid(state_store):
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _context_key_for_context(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = context.get("entity_id", StringName())
	return _variant_to_string_name(entity_id_variant)

func _resolve_rule_id(rule_variant: Variant) -> StringName:
	var rule_id_variant: Variant = _read_object_property(rule_variant, "rule_id")
	var rule_id: StringName = _variant_to_string_name(rule_id_variant)
	if rule_id != StringName():
		return rule_id
	if rule_variant is Object:
		return StringName("__ai_goal_rule_%d" % (rule_variant as Object).get_instance_id())
	return StringName("__ai_goal_rule")

func _read_bool_property(object_value: Variant, property_name: String, fallback: bool) -> bool:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = _read_object_property(object_value, property_name)
	if value is bool:
		return value
	if value is int:
		return value != 0
	return fallback

func _read_float_property(object_value: Variant, property_name: String, fallback: float) -> float:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = _read_object_property(object_value, property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _read_int_property(object_value: Variant, property_name: String, fallback: int) -> int:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = _read_object_property(object_value, property_name)
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback

func _read_object_property(object_value: Variant, property_name: String) -> Variant:
	if object_value == null or not (object_value is Object):
		return null
	return object_value.get(property_name)

func _variant_to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	if value is String:
		var text: String = value
		if text.is_empty():
			return StringName()
		return StringName(text)
	return StringName()
