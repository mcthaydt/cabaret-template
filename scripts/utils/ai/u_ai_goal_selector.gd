extends RefCounted
class_name U_AIGoalSelector

const RS_RULE := preload("res://scripts/resources/qb/rs_rule.gd")
const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_RULE_SELECTOR := preload("res://scripts/utils/qb/u_rule_selector.gd")

const GOAL_DECISION_GROUP := StringName("ai_goal")

var _rule_pool: Dictionary = {}
var _goal_by_id_cache: Dictionary = {}

func select(
	brain_settings: RS_AIBrainSettings,
	context: Dictionary,
	tracker: U_RuleStateTracker,
	executing_goal_id: StringName = StringName()
) -> RS_AIGoal:
	if brain_settings == null:
		return null

	var goals: Array[RS_AIGoal] = brain_settings.goals
	var default_goal_id: StringName = brain_settings.default_goal_id
	if goals.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var goal_rules: Array = []
	var goal_by_rule: Dictionary = {}
	for goal: RS_AIGoal in goals:
		var goal_rule: RS_Rule = _build_rule_from_goal(goal)
		if goal_rule == null:
			continue
		goal_rules.append(goal_rule)
		goal_by_rule[goal_rule] = goal

	if goal_rules.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var scored: Array[Dictionary] = U_RULE_SCORER.score_rules(goal_rules, context)
	if scored.is_empty():
		return _find_goal_by_id(goals, default_goal_id)

	var gated: Array[Dictionary] = _apply_state_gates(
		goal_rules,
		scored,
		context,
		tracker,
		executing_goal_id
	)
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
		return goal_by_rule.get(winning_rule) as RS_AIGoal

	return _find_goal_by_id(goals, default_goal_id)

func mark_goal_fired(goal: RS_AIGoal, context: Dictionary, tracker: U_RuleStateTracker) -> void:
	if goal == null:
		return
	var rule: RS_Rule = _build_rule_from_goal(goal)
	_mark_goal_rule_fired(rule, context, tracker)

func mark_goal_fired_by_id(
	brain_settings: RS_AIBrainSettings,
	goal_id: StringName,
	context: Dictionary,
	tracker: U_RuleStateTracker
) -> void:
	if brain_settings == null:
		return
	if goal_id == StringName():
		return
	var goal: RS_AIGoal = _find_goal_by_id(brain_settings.goals, goal_id)
	mark_goal_fired(goal, context, tracker)

func get_rule_pool() -> Dictionary:
	return _rule_pool

func get_goal_cache() -> Dictionary:
	return _goal_by_id_cache

func _build_rule_from_goal(goal: RS_AIGoal) -> RS_Rule:
	if goal == null:
		return null

	var goal_id: StringName = _read_goal_id(goal)
	if goal_id == StringName():
		goal_id = StringName("__ai_goal_%d" % (goal as Object).get_instance_id())

	if _rule_pool.has(goal_id):
		var cached_rule: RS_Rule = _rule_pool[goal_id] as RS_Rule
		cached_rule.priority = goal.priority
		cached_rule.conditions = _read_conditions(goal)
		cached_rule.score_threshold = goal.score_threshold
		cached_rule.cooldown = goal.cooldown
		cached_rule.one_shot = goal.one_shot
		cached_rule.requires_rising_edge = goal.requires_rising_edge
		return cached_rule

	var rule: RS_Rule = RS_RULE.new()
	rule.rule_id = goal_id
	rule.decision_group = GOAL_DECISION_GROUP
	rule.priority = goal.priority
	rule.conditions = _read_conditions(goal)
	rule.score_threshold = goal.score_threshold
	rule.cooldown = goal.cooldown
	rule.one_shot = goal.one_shot
	rule.requires_rising_edge = goal.requires_rising_edge

	_rule_pool[goal_id] = rule
	return rule

func _apply_state_gates(
	rules: Array,
	scored: Array[Dictionary],
	context: Dictionary,
	tracker: U_RuleStateTracker,
	executing_goal_id: StringName = StringName()
) -> Array[Dictionary]:
	if tracker == null:
		return scored

	var context_key: StringName = _context_key_for_context(context)
	var scored_by_rule: Dictionary = {}
	for result: Dictionary in scored:
		var rule_variant: Variant = result.get("rule", null)
		if rule_variant != null:
			scored_by_rule[rule_variant] = result

	var gated: Array[Dictionary] = []
	for rule_variant in rules:
		if not (rule_variant is RS_Rule):
			continue
		var rule: RS_Rule = rule_variant as RS_Rule

		var rule_id: StringName = _resolve_rule_id(rule)
		var is_executing: bool = executing_goal_id != StringName() and rule_id == executing_goal_id
		var is_passing_now: bool = scored_by_rule.has(rule)
		var has_rising_edge: bool = true
		if rule.requires_rising_edge:
			has_rising_edge = tracker.check_rising_edge(rule_id, context_key, is_passing_now)

		if not is_passing_now:
			continue
		if not is_executing:
			if tracker.is_one_shot_spent(rule_id, context_key):
				continue
			if tracker.is_on_cooldown(rule_id, context_key):
				continue
			if rule.requires_rising_edge and not has_rising_edge:
				continue

		var result_variant: Variant = scored_by_rule.get(rule, null)
		if result_variant is Dictionary:
			gated.append(result_variant as Dictionary)

	return gated

func _mark_goal_rule_fired(rule: RS_Rule, context: Dictionary, tracker: U_RuleStateTracker) -> void:
	if rule == null or tracker == null:
		return

	var context_key: StringName = _context_key_for_context(context)
	var rule_id: StringName = _resolve_rule_id(rule)
	var cooldown: float = maxf(rule.cooldown, 0.0)
	tracker.mark_fired(rule_id, context_key, cooldown)
	if rule.one_shot:
		tracker.mark_one_shot_spent(rule_id, context_key)

func _find_goal_by_id(goals: Array[RS_AIGoal], goal_id: StringName) -> RS_AIGoal:
	if goal_id == StringName():
		return null

	var cache_key: int = goals.hash()
	if not _goal_by_id_cache.has(cache_key):
		var lookup: Dictionary = {}
		for goal: RS_AIGoal in goals:
			if goal == null:
				continue
			lookup[_read_goal_id(goal)] = goal
		_goal_by_id_cache[cache_key] = lookup
	var cached_lookup: Dictionary = _goal_by_id_cache[cache_key] as Dictionary
	if cached_lookup.has(goal_id):
		return cached_lookup[goal_id] as RS_AIGoal
	return null

func _read_conditions(goal: RS_AIGoal) -> Array[I_Condition]:
	var conditions: Array[I_Condition] = []
	for condition: I_Condition in goal.conditions:
		if condition != null:
			conditions.append(condition)
	return conditions

func _read_goal_id(goal: RS_AIGoal) -> StringName:
	if goal == null:
		return StringName()
	return goal.goal_id

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

func _resolve_rule_id(rule: RS_Rule) -> StringName:
	if rule == null:
		return StringName("__ai_goal_rule")
	if rule.rule_id != StringName():
		return rule.rule_id
	return StringName("__ai_goal_rule_%d" % (rule as Object).get_instance_id())
