extends BaseTest

const BASE_QB_RULE_MANAGER := preload("res://scripts/ecs/systems/base_qb_rule_manager.gd")
const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")


class RuleManagerStub:
	extends "res://scripts/ecs/systems/base_qb_rule_manager.gd"

	var contexts: Array = []
	var default_rules: Array = []

	func _get_tick_contexts(_delta: float) -> Array:
		return contexts

	func get_default_rule_definitions() -> Array:
		return default_rules

	func _should_emit_rule_validation_warnings() -> bool:
		return false


var _fired_effects: Array = []


func before_each() -> void:
	U_ECSEventBus.reset()
	_fired_effects = []


func _configure_manager(rules: Array = []) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var manager := RuleManagerStub.new()
	manager.rule_definitions = rules
	manager.state_store = store
	manager.ecs_manager = ecs_manager
	autofree(manager)
	manager.configure(ecs_manager)

	return {"manager": manager, "store": store, "ecs_manager": ecs_manager}


func _make_bool_condition(path: String) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.CUSTOM
	condition.quality_path = path
	condition.operator = QB_CONDITION.Operator.IS_TRUE
	condition.value_type = QB_CONDITION.ValueType.BOOL
	return condition


func _make_float_condition_with_curve(path: String, min_val: float, max_val: float) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.CUSTOM
	condition.quality_path = path
	condition.operator = QB_CONDITION.Operator.GTE
	condition.value_type = QB_CONDITION.ValueType.FLOAT
	condition.value_float = 0.0

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	condition.score_curve = curve
	condition.normalize_min = min_val
	condition.normalize_max = max_val

	return condition


func _make_event_effect(event_name: StringName) -> Variant:
	var effect: Variant = QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.PUBLISH_EVENT
	effect.target = String(event_name)
	return effect


func _make_rule(
	rule_id: StringName,
	conditions: Array,
	effects: Array,
	decision_group: StringName = &"",
	requires_salience: bool = false,
	priority: int = 0
) -> Variant:
	var rule: Variant = QB_RULE.new()
	rule.rule_id = rule_id
	rule.conditions = conditions
	rule.effects = effects
	rule.decision_group = decision_group
	rule.requires_salience = requires_salience
	rule.priority = priority
	return rule


func _make_quality_effect(target: StringName, value: bool) -> Variant:
	var effect: Variant = QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.SET_QUALITY
	effect.target = String(target)
	effect.payload = {"value_type": "BOOL", "value_bool": value}
	return effect


func test_two_rules_same_group_only_highest_score_fires() -> void:
	# Both rules use same curve path so same score; alphabetical tiebreak: high_score_rule < low_score_rule.
	var low_condition: Variant = _make_float_condition_with_curve("score_val", 0.0, 100.0)
	var high_condition: Variant = _make_float_condition_with_curve("score_val", 0.0, 100.0)

	var low_rule: Variant = _make_rule(
		&"low_score_rule",
		[low_condition],
		[_make_event_effect(&"low_score_event")],
		&"test_group"
	)
	var high_rule: Variant = _make_rule(
		&"high_score_rule",
		[high_condition],
		[_make_event_effect(&"high_score_event")],
		&"test_group"
	)

	var result: Dictionary = _configure_manager([low_rule, high_rule])
	var manager: Variant = result["manager"]

	manager.contexts = [{"score_val": 80.0}]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_false(fired_names.has(&"low_score_event"), "Low-score rule should not fire when grouped with higher")
	assert_true(fired_names.has(&"high_score_event"), "High-score rule should fire as group winner")


func test_two_rules_same_group_same_score_priority_tiebreak() -> void:
	var condition_a: Variant = _make_bool_condition("flag")
	var condition_b: Variant = _make_bool_condition("flag")

	var low_priority_rule: Variant = _make_rule(
		&"rule_low_priority",
		[condition_a],
		[_make_event_effect(&"low_priority_event")],
		&"priority_group",
		false,
		0
	)
	var high_priority_rule: Variant = _make_rule(
		&"rule_high_priority",
		[condition_b],
		[_make_event_effect(&"high_priority_event")],
		&"priority_group",
		false,
		10
	)

	var result: Dictionary = _configure_manager([low_priority_rule, high_priority_rule])
	var manager: Variant = result["manager"]

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_false(fired_names.has(&"low_priority_event"), "Lower priority rule should not fire")
	assert_true(fired_names.has(&"high_priority_event"), "Higher priority rule should win tiebreak")


func test_three_rules_same_group_same_score_same_priority_alphabetical_tiebreak() -> void:
	var condition_a: Variant = _make_bool_condition("flag")
	var condition_b: Variant = _make_bool_condition("flag")
	var condition_c: Variant = _make_bool_condition("flag")

	var rule_z: Variant = _make_rule(&"rule_zzz", [condition_a], [_make_event_effect(&"zzz_fired_alpha")], &"alpha_group")
	var rule_a: Variant = _make_rule(&"rule_aaa", [condition_b], [_make_event_effect(&"aaa_fired_alpha")], &"alpha_group")
	var rule_m: Variant = _make_rule(&"rule_mmm", [condition_c], [_make_event_effect(&"mmm_fired_alpha")], &"alpha_group")

	var result: Dictionary = _configure_manager([rule_z, rule_a, rule_m])
	var manager: Variant = result["manager"]

	manager.contexts = [{"flag": true}]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_true(fired_names.has(&"aaa_fired_alpha"), "Alphabetically earliest rule_id should win")
	assert_false(fired_names.has(&"mmm_fired_alpha"), "rule_mmm should not fire")
	assert_false(fired_names.has(&"zzz_fired_alpha"), "rule_zzz should not fire")


func test_rules_in_different_groups_both_fire() -> void:
	var condition_a: Variant = _make_bool_condition("flag_a")
	var condition_b: Variant = _make_bool_condition("flag_b")

	var rule_a: Variant = _make_rule(&"group_a_rule", [condition_a], [_make_event_effect(&"group_a_event")], &"group_a")
	var rule_b: Variant = _make_rule(&"group_b_rule", [condition_b], [_make_event_effect(&"group_b_event")], &"group_b")

	var result: Dictionary = _configure_manager([rule_a, rule_b])
	var manager: Variant = result["manager"]

	manager.contexts = [{"flag_a": true, "flag_b": true}]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_true(fired_names.has(&"group_a_event"), "Group A rule should fire")
	assert_true(fired_names.has(&"group_b_event"), "Group B rule should fire")


func test_rules_with_no_group_fire_independently() -> void:
	var condition_a: Variant = _make_bool_condition("flag_a")
	var condition_b: Variant = _make_bool_condition("flag_b")

	var rule_a: Variant = _make_rule(&"independent_a", [condition_a], [_make_event_effect(&"ind_a_event")])
	var rule_b: Variant = _make_rule(&"independent_b", [condition_b], [_make_event_effect(&"ind_b_event")])

	var result: Dictionary = _configure_manager([rule_a, rule_b])
	var manager: Variant = result["manager"]

	manager.contexts = [{"flag_a": true, "flag_b": true}]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_true(fired_names.has(&"ind_a_event"), "Independent rule A should fire")
	assert_true(fired_names.has(&"ind_b_event"), "Independent rule B should fire")


func test_all_rules_in_group_false_no_effect_fires() -> void:
	var condition: Variant = _make_bool_condition("flag")

	var rule: Variant = _make_rule(&"never_fires", [condition], [_make_event_effect(&"should_not_fire_event")], &"empty_group")

	var result: Dictionary = _configure_manager([rule])
	var manager: Variant = result["manager"]

	manager.contexts = [{"flag": false}]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_false(fired_names.has(&"should_not_fire_event"), "No effect should fire when all group conditions are false")


func test_salience_state_tracked_for_losing_rules() -> void:
	# Rule A ("high_s_rule") and Rule B ("low_s_rule") compete in the same group.
	# Both use the same score_val path, same curve, so they tie. Alphabetical: high_s_rule < low_s_rule.
	# "high_s_rule" wins the tiebreak. "low_s_rule" loses competition on tick 1.
	# Salience is tracked for both. On tick 3 conditions go false, tick 4 they return true.
	# Both become candidates again; high_s_rule still wins.

	var high_condition: Variant = _make_float_condition_with_curve("score_val", 0.0, 100.0)
	var low_condition: Variant = _make_float_condition_with_curve("score_val", 0.0, 100.0)

	var high_rule: Variant = _make_rule(
		&"high_s_rule",
		[high_condition],
		[_make_event_effect(&"high_s_event")],
		&"salience_group",
		true
	)
	var low_rule: Variant = _make_rule(
		&"low_s_rule",
		[low_condition],
		[_make_event_effect(&"low_s_event")],
		&"salience_group",
		true
	)

	var result: Dictionary = _configure_manager([high_rule, low_rule])
	var manager: Variant = result["manager"]

	# Tick 1: Both conditions true. high_s_rule wins (alphabetical tiebreak). low_s_rule loses.
	manager.contexts = [{"score_val": 80.0}]
	manager.process_tick(0.1)

	var history_t1: Array = U_ECSEventBus.get_event_history()
	var names_t1: Array[StringName] = []
	for e in history_t1:
		names_t1.append(StringName(String(e.get("name", ""))))
	assert_true(names_t1.has(&"high_s_event"), "High rule should fire tick 1")
	assert_false(names_t1.has(&"low_s_event"), "Low rule should not fire tick 1 (lost competition)")

	# Tick 2: Both still true. Salience blocks both (was_true_before = true for both).
	U_ECSEventBus.clear_history()
	manager.process_tick(0.1)
	var history_t2: Array = U_ECSEventBus.get_event_history()
	assert_eq(history_t2.size(), 0, "No rules should fire on tick 2 (salience blocks)")

	# Tick 3: Conditions go false (score_val < 0.0, GTE 0.0 fails). Resets was_true state.
	manager.contexts = [{"score_val": -1.0}]
	U_ECSEventBus.clear_history()
	manager.process_tick(0.1)

	# Tick 4: Conditions go true again. Both are candidates (false→true transition). High wins.
	manager.contexts = [{"score_val": 80.0}]
	U_ECSEventBus.clear_history()
	manager.process_tick(0.1)
	var history_t4: Array = U_ECSEventBus.get_event_history()
	var names_t4: Array[StringName] = []
	for e in history_t4:
		names_t4.append(StringName(String(e.get("name", ""))))
	assert_true(names_t4.has(&"high_s_event"), "High rule should fire again on retransition")
	assert_false(names_t4.has(&"low_s_event"), "Low rule still loses competition on tick 4")


func test_per_context_independent_winner_selection() -> void:
	# Entity A context has high score_x and low score_y → rule_x wins for A.
	# Entity B context has low score_x and high score_y → rule_y wins for B.
	# Both rules are in the same group, so only one fires per context — but the
	# winner differs between contexts, proving per-context scoping works correctly.

	var condition_x: Variant = _make_float_condition_with_curve("score_x", 0.0, 100.0)
	var condition_y: Variant = _make_float_condition_with_curve("score_y", 0.0, 100.0)

	var rule_x: Variant = _make_rule(&"rule_x", [condition_x], [_make_event_effect(&"x_event")], &"ctx_group")
	var rule_y: Variant = _make_rule(&"rule_y", [condition_y], [_make_event_effect(&"y_event")], &"ctx_group")

	var result: Dictionary = _configure_manager([rule_x, rule_y])
	var manager: Variant = result["manager"]

	var ctx_a: Dictionary = {"entity_id": "entity_a", "score_x": 80.0, "score_y": 20.0}
	var ctx_b: Dictionary = {"entity_id": "entity_b", "score_x": 20.0, "score_y": 80.0}
	manager.contexts = [ctx_a, ctx_b]
	manager.process_tick(0.1)

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_true(fired_names.has(&"x_event"), "rule_x should win for entity_a (higher score_x)")
	assert_true(fired_names.has(&"y_event"), "rule_y should win for entity_b (higher score_y)")


func test_event_rule_in_decision_group_participates_in_scoring() -> void:
	# Two EVENT-triggered rules in the same decision group both become candidates when
	# the trigger event fires (salience auto-disabled for events). Only the winner
	# fires — group selection applies even though salience is bypassed.
	# Alphabetical tiebreak: "alpha_event_rule" < "beta_event_rule" → alpha wins.

	var rule_alpha: Variant = QB_RULE.new()
	rule_alpha.rule_id = &"alpha_event_rule"
	rule_alpha.trigger_mode = QB_RULE.TriggerMode.EVENT
	rule_alpha.trigger_event = &"group_test_event"
	rule_alpha.effects = [_make_event_effect(&"alpha_event_fired")]
	rule_alpha.decision_group = &"event_grp"

	var rule_beta: Variant = QB_RULE.new()
	rule_beta.rule_id = &"beta_event_rule"
	rule_beta.trigger_mode = QB_RULE.TriggerMode.EVENT
	rule_beta.trigger_event = &"group_test_event"
	rule_beta.effects = [_make_event_effect(&"beta_event_fired")]
	rule_beta.decision_group = &"event_grp"

	var result: Dictionary = _configure_manager([rule_alpha, rule_beta])

	U_ECSEventBus.publish(&"group_test_event", {})

	var history: Array = U_ECSEventBus.get_event_history()
	var fired_names: Array[StringName] = []
	for entry in history:
		fired_names.append(StringName(String(entry.get("name", ""))))

	assert_true(fired_names.has(&"alpha_event_fired"), "Alphabetically earlier event rule should win the group")
	assert_false(fired_names.has(&"beta_event_fired"), "beta_event_rule should be outcompeted in the group")


func test_one_shot_winner_disabled_next_runner_up_wins() -> void:
	var condition_a: Variant = _make_bool_condition("flag")
	var condition_b: Variant = _make_bool_condition("flag")

	var one_shot_rule: Variant = _make_rule(
		&"one_shot_high",
		[condition_a],
		[_make_event_effect(&"one_shot_event")],
		&"oneshot_group",
		false,
		10
	)
	one_shot_rule.is_one_shot = true

	var fallback_rule: Variant = _make_rule(
		&"fallback_low",
		[condition_b],
		[_make_event_effect(&"fallback_event")],
		&"oneshot_group",
		false,
		0
	)

	var result: Dictionary = _configure_manager([one_shot_rule, fallback_rule])
	var manager: Variant = result["manager"]

	# Tick 1: one_shot_high wins (higher priority), fires, then gets disabled.
	manager.contexts = [{"flag": true}]
	manager.process_tick(0.1)

	var history_t1: Array = U_ECSEventBus.get_event_history()
	var names_t1: Array[StringName] = []
	for e in history_t1:
		names_t1.append(StringName(String(e.get("name", ""))))
	assert_true(names_t1.has(&"one_shot_event"), "One-shot rule fires tick 1")
	assert_false(names_t1.has(&"fallback_event"), "Fallback does not fire tick 1")

	# Tick 2: one_shot_high is disabled; fallback_low wins group.
	U_ECSEventBus.clear_history()
	manager.process_tick(0.1)
	var history_t2: Array = U_ECSEventBus.get_event_history()
	var names_t2: Array[StringName] = []
	for e in history_t2:
		names_t2.append(StringName(String(e.get("name", ""))))
	assert_false(names_t2.has(&"one_shot_event"), "One-shot rule is disabled, does not fire again")
	assert_true(names_t2.has(&"fallback_event"), "Fallback rule wins after one-shot is disabled")
