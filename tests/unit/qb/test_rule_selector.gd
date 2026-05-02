extends BaseTest

const RULE_SELECTOR := preload("res://scripts/core/utils/qb/u_rule_selector.gd")
const RULE_RESOURCE := preload("res://scripts/core/resources/qb/rs_rule.gd")

func _make_rule(rule_id: StringName, decision_group: StringName = StringName(), priority: int = 0) -> Variant:
	var rule: Variant = RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.decision_group = decision_group
	rule.priority = priority
	return rule

func _make_scored(rule: Variant, score: float) -> Dictionary:
	return {
		"rule": rule,
		"score": score
	}

func test_ungrouped_rules_all_appear_in_winners() -> void:
	var rule_a: Variant = _make_rule(StringName("a"))
	var rule_b: Variant = _make_rule(StringName("b"))
	var scored: Array = [
		_make_scored(rule_a, 0.4),
		_make_scored(rule_b, 0.9)
	]

	var winners: Array = RULE_SELECTOR.select_winners(scored)
	assert_eq(winners.size(), 2)
	assert_true(winners.has(scored[0]))
	assert_true(winners.has(scored[1]))

func test_grouped_rules_highest_score_wins() -> void:
	var low: Variant = _make_rule(StringName("low"), StringName("group_a"), 0)
	var high: Variant = _make_rule(StringName("high"), StringName("group_a"), 0)
	var scored: Array = [
		_make_scored(low, 0.2),
		_make_scored(high, 0.8)
	]

	var winners: Array = RULE_SELECTOR.select_winners(scored)
	assert_eq(winners.size(), 1)
	assert_eq((winners[0] as Dictionary).get("rule"), high)

func test_grouped_rules_priority_tiebreak_when_scores_equal() -> void:
	var low_priority: Variant = _make_rule(StringName("low_priority"), StringName("group_a"), 1)
	var high_priority: Variant = _make_rule(StringName("high_priority"), StringName("group_a"), 5)
	var scored: Array = [
		_make_scored(low_priority, 0.7),
		_make_scored(high_priority, 0.7)
	]

	var winners: Array = RULE_SELECTOR.select_winners(scored)
	assert_eq(winners.size(), 1)
	assert_eq((winners[0] as Dictionary).get("rule"), high_priority)

func test_grouped_rules_rule_id_alphabetical_tiebreak_when_score_and_priority_equal() -> void:
	var alpha: Variant = _make_rule(StringName("alpha"), StringName("group_a"), 1)
	var zulu: Variant = _make_rule(StringName("zulu"), StringName("group_a"), 1)
	var scored: Array = [
		_make_scored(zulu, 0.7),
		_make_scored(alpha, 0.7)
	]

	var winners: Array = RULE_SELECTOR.select_winners(scored)
	assert_eq(winners.size(), 1)
	assert_eq((winners[0] as Dictionary).get("rule"), alpha)

func test_mixed_grouped_and_ungrouped_results_include_both() -> void:
	var ungrouped: Variant = _make_rule(StringName("ungrouped"))
	var grouped_a: Variant = _make_rule(StringName("grouped_a"), StringName("group_a"))
	var grouped_b: Variant = _make_rule(StringName("grouped_b"), StringName("group_a"))
	var scored_grouped_winner: Dictionary = _make_scored(grouped_b, 0.8)
	var scored: Array = [
		_make_scored(ungrouped, 0.3),
		_make_scored(grouped_a, 0.2),
		scored_grouped_winner
	]

	var winners: Array = RULE_SELECTOR.select_winners(scored)
	assert_eq(winners.size(), 2)
	assert_true(winners.has(scored[0]))
	assert_true(winners.has(scored_grouped_winner))

func test_multiple_decision_groups_each_produce_one_winner() -> void:
	var group_a_1: Variant = _make_rule(StringName("group_a_1"), StringName("group_a"))
	var group_a_2: Variant = _make_rule(StringName("group_a_2"), StringName("group_a"))
	var group_b_1: Variant = _make_rule(StringName("group_b_1"), StringName("group_b"))
	var group_b_2: Variant = _make_rule(StringName("group_b_2"), StringName("group_b"))
	var scored: Array = [
		_make_scored(group_a_1, 0.2),
		_make_scored(group_a_2, 0.6),
		_make_scored(group_b_1, 0.9),
		_make_scored(group_b_2, 0.5)
	]

	var winners: Array = RULE_SELECTOR.select_winners(scored)
	assert_eq(winners.size(), 2)

	var winner_rules: Array = []
	for winner_variant in winners:
		var winner: Dictionary = winner_variant as Dictionary
		winner_rules.append(winner.get("rule"))

	assert_true(winner_rules.has(group_a_2))
	assert_true(winner_rules.has(group_b_1))

func test_empty_input_returns_empty_winners() -> void:
	var winners: Array = RULE_SELECTOR.select_winners([])
	assert_true(winners.is_empty())
