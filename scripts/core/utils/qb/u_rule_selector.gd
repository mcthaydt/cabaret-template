extends RefCounted
class_name U_RuleSelector

const U_RULE_UTILS := preload("res://scripts/core/utils/ecs/u_rule_utils.gd")

static func select_winners(scored_results: Array) -> Array[Dictionary]:
	if scored_results.is_empty():
		return []

	var ungrouped: Array[Dictionary] = []
	var grouped: Dictionary = {}

	for result_variant in scored_results:
		if not (result_variant is Dictionary):
			continue
		var result: Dictionary = result_variant as Dictionary
		var rule: Variant = result.get("rule", null)
		if rule == null or not (rule is Object):
			continue

		var decision_group: StringName = U_RULE_UTILS.read_string_name_property(rule, "decision_group")
		if decision_group == StringName():
			ungrouped.append(result)
			continue

		if not grouped.has(decision_group):
			grouped[decision_group] = []
		var group_entries: Array = grouped.get(decision_group, [])
		group_entries.append(result)
		grouped[decision_group] = group_entries

	var winners: Array[Dictionary] = []
	for result in ungrouped:
		winners.append(result)

	for group_key in grouped.keys():
		var entries: Array = grouped.get(group_key, [])
		var best: Dictionary = _pick_best_candidate(entries)
		if not best.is_empty():
			winners.append(best)

	return winners

static func _pick_best_candidate(entries: Array) -> Dictionary:
	if entries.is_empty():
		return {}

	var best_variant: Variant = entries[0]
	if not (best_variant is Dictionary):
		return {}
	var best: Dictionary = best_variant as Dictionary

	for i in range(1, entries.size()):
		var current_variant: Variant = entries[i]
		if not (current_variant is Dictionary):
			continue
		var current: Dictionary = current_variant as Dictionary
		if _is_better_candidate(current, best):
			best = current

	return best

static func _is_better_candidate(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_score: float = _read_score(candidate)
	var incumbent_score: float = _read_score(incumbent)
	if candidate_score > incumbent_score:
		return true
	if candidate_score < incumbent_score:
		return false

	var candidate_rule: Variant = candidate.get("rule", null)
	var incumbent_rule: Variant = incumbent.get("rule", null)
	var candidate_priority: int = U_RULE_UTILS.read_int_property(candidate_rule, "priority", 0)
	var incumbent_priority: int = U_RULE_UTILS.read_int_property(incumbent_rule, "priority", 0)
	if candidate_priority > incumbent_priority:
		return true
	if candidate_priority < incumbent_priority:
		return false

	var candidate_rule_id: String = U_RULE_UTILS.read_string_name_property(candidate_rule, "rule_id")
	var incumbent_rule_id: String = U_RULE_UTILS.read_string_name_property(incumbent_rule, "rule_id")
	return candidate_rule_id.naturalnocasecmp_to(incumbent_rule_id) < 0

static func _read_score(entry: Dictionary) -> float:
	var score_variant: Variant = entry.get("score", 0.0)
	if score_variant is float or score_variant is int:
		return float(score_variant)
	return 0.0