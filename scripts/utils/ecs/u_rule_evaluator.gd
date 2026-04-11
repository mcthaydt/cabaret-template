extends RefCounted
class_name U_RuleEvaluator

const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_RULE_SELECTOR := preload("res://scripts/utils/qb/u_rule_selector.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_RULE_VALIDATOR := preload("res://scripts/utils/qb/u_rule_validator.gd")
const IGNORABLE_VALIDATION_ERRORS_EXACT := [
	"rule_id must be non-empty",
	"event/both trigger modes require an RS_ConditionEventName condition",
]

const TRIGGER_MODE_TICK := "tick"
const TRIGGER_MODE_EVENT := "event"
const TRIGGER_MODE_BOTH := "both"

var _tracker: U_RuleStateTracker = RULE_STATE_TRACKER.new()
var _active_rules: Array = []
var _rule_validation_report: Dictionary = {}
var _event_unsubscribers: Array[Callable] = []
var _has_tick_rules: bool = false

func refresh(default_rules: Array, custom_rules: Array = []) -> void:
	var combined_rules: Array = default_rules.duplicate()
	for rule_variant in custom_rules:
		combined_rules.append(rule_variant)

	var base_report: Dictionary = U_RULE_VALIDATOR.validate_rules(combined_rules)
	_rule_validation_report = _sanitize_validation_report(combined_rules, base_report)
	var valid_rules_variant: Variant = _rule_validation_report.get("valid_rules", [])
	if valid_rules_variant is Array:
		_active_rules = (valid_rules_variant as Array).duplicate()
	else:
		_active_rules = []

	_has_tick_rules = false
	for rule_variant in _active_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue
		if _supports_trigger_mode(rule_variant, TRIGGER_MODE_TICK):
			_has_tick_rules = true
			break

func get_rule_validation_report() -> Dictionary:
	return _rule_validation_report.duplicate(true)

func has_tick_rules() -> bool:
	return _has_tick_rules

func tick_cooldowns(delta: float) -> void:
	_tracker.tick_cooldowns(delta)

func cleanup_stale_contexts(active_context_keys: Array) -> void:
	_tracker.cleanup_stale_contexts(active_context_keys)

func get_applicable_rules(
	trigger_mode: String,
	event_name: StringName = StringName(),
	rule_filter: Callable = Callable()
) -> Array:
	var applicable_rules: Array = []
	for rule_variant in _active_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue
		if not _supports_trigger_mode(rule_variant, trigger_mode):
			continue
		if rule_filter.is_valid() and not bool(rule_filter.call(rule_variant, event_name)):
			continue
		applicable_rules.append(rule_variant)
	return applicable_rules

func subscribe(extract_event_names: Callable, on_event: Callable) -> void:
	unsubscribe()
	if not extract_event_names.is_valid() or not on_event.is_valid():
		return

	var subscribed_events: Dictionary = {}
	var event_rules: Array = get_applicable_rules(TRIGGER_MODE_EVENT)
	for rule_variant in event_rules:
		var event_names_variant: Variant = extract_event_names.call(rule_variant)
		if not (event_names_variant is Array):
			continue

		for event_name_variant in (event_names_variant as Array):
			var event_name: StringName = U_RuleUtils.variant_to_string_name(event_name_variant)
			if event_name == StringName() or subscribed_events.has(event_name):
				continue

			var subscribed_event_name: StringName = event_name
			var unsubscribe_callable: Callable = U_ECS_EVENT_BUS.subscribe(
				subscribed_event_name,
				func(event_data: Dictionary) -> void:
					on_event.call(subscribed_event_name, _extract_event_payload(event_data))
			)
			if unsubscribe_callable.is_valid():
				_event_unsubscribers.append(unsubscribe_callable)
				subscribed_events[subscribed_event_name] = true

func unsubscribe() -> void:
	for unsubscribe_callable in _event_unsubscribers:
		if unsubscribe_callable.is_valid():
			unsubscribe_callable.call()
	_event_unsubscribers.clear()

func evaluate(
	context: Dictionary,
	trigger_mode: String,
	event_name: StringName = StringName(),
	context_key: StringName = StringName(),
	rule_filter: Callable = Callable(),
	winner_executor: Callable = Callable()
) -> Array[Dictionary]:
	var applicable_rules: Array = get_applicable_rules(trigger_mode, event_name, rule_filter)
	if applicable_rules.is_empty():
		return []

	var scored: Array[Dictionary] = U_RULE_SCORER.score_rules(applicable_rules, context)
	var gated: Array[Dictionary] = _apply_state_gates(applicable_rules, scored, context_key)
	if gated.is_empty():
		return []

	var winners: Array[Dictionary] = U_RULE_SELECTOR.select_winners(gated)
	if winners.is_empty():
		return []

	if winner_executor.is_valid():
		winner_executor.call(winners, context)
	else:
		_execute_winner_effects(winners, context)

	_mark_winners_fired(winners, context_key)
	return winners

func _supports_trigger_mode(rule_variant: Variant, trigger_mode: String) -> bool:
	var rule_trigger_mode: String = U_RuleUtils.read_string_property(rule_variant, "trigger_mode", TRIGGER_MODE_TICK)
	if trigger_mode == TRIGGER_MODE_TICK:
		return rule_trigger_mode == TRIGGER_MODE_TICK or rule_trigger_mode == TRIGGER_MODE_BOTH
	if trigger_mode == TRIGGER_MODE_EVENT:
		return rule_trigger_mode == TRIGGER_MODE_EVENT or rule_trigger_mode == TRIGGER_MODE_BOTH
	return false

func _apply_state_gates(
	applicable_rules: Array,
	scored: Array[Dictionary],
	context_key: StringName
) -> Array[Dictionary]:
	var scored_by_rule: Dictionary = {}
	for result in scored:
		var rule_variant: Variant = result.get("rule", null)
		if rule_variant == null:
			continue
		scored_by_rule[rule_variant] = result

	var gated: Array[Dictionary] = []
	for rule_variant in applicable_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue

		var rule_id: StringName = _resolve_rule_id(rule_variant)
		var requires_rising_edge: bool = U_RuleUtils.read_bool_property(rule_variant, "requires_rising_edge", false)
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
			gated.append(result_variant)

	return gated

func _execute_winner_effects(winners: Array[Dictionary], context: Dictionary) -> void:
	for winner in winners:
		var rule_variant: Variant = winner.get("rule", null)
		if rule_variant == null or not (rule_variant is Object):
			continue

		var effects_variant: Variant = rule_variant.get("effects")
		if not (effects_variant is Array):
			continue

		for effect_variant in (effects_variant as Array):
			if effect_variant == null or not (effect_variant is Object):
				continue
			if not effect_variant is I_Effect:
				continue
			effect_variant.call("execute", context)

func _mark_winners_fired(winners: Array[Dictionary], context_key: StringName) -> void:
	for winner in winners:
		var rule_variant: Variant = winner.get("rule", null)
		if rule_variant == null or not (rule_variant is Object):
			continue

		var rule_id: StringName = _resolve_rule_id(rule_variant)
		var cooldown: float = maxf(U_RuleUtils.read_float_property(rule_variant, "cooldown", 0.0), 0.0)
		_tracker.mark_fired(rule_id, context_key, cooldown)
		if U_RuleUtils.read_bool_property(rule_variant, "one_shot", false):
			_tracker.mark_one_shot_spent(rule_id)

func _extract_event_payload(event_data: Dictionary) -> Dictionary:
	var payload_variant: Variant = event_data.get("payload", {})
	if payload_variant is Dictionary:
		return (payload_variant as Dictionary).duplicate(true)
	return {}

func _resolve_rule_id(rule_variant: Variant) -> StringName:
	var rule_id: StringName = U_RuleUtils.read_string_name_property(rule_variant, "rule_id")
	if rule_id != StringName():
		return rule_id
	if rule_variant is Object:
		return StringName("__rule_%d" % (rule_variant as Object).get_instance_id())
	return StringName("__rule")

func _sanitize_validation_report(combined_rules: Array, base_report: Dictionary) -> Dictionary:
	var valid_rules: Array = []
	var errors_by_index: Dictionary = {}
	var errors_by_rule_id: Dictionary = {}
	var warnings_by_index: Dictionary = base_report.get("warnings_by_index", {}).duplicate(true)
	var warnings_by_rule_id: Dictionary = base_report.get("warnings_by_rule_id", {}).duplicate(true)
	var base_errors_by_index: Dictionary = base_report.get("errors_by_index", {})

	for index in range(combined_rules.size()):
		var rule_variant: Variant = combined_rules[index]
		var raw_errors_variant: Variant = base_errors_by_index.get(index, [])
		var filtered_errors: Array[String] = []
		if raw_errors_variant is Array:
			for error_variant in (raw_errors_variant as Array):
				var error_text: String = str(error_variant)
				if _is_ignorable_validation_error(error_text):
					continue
				filtered_errors.append(error_text)

		if filtered_errors.is_empty():
			if rule_variant != null and rule_variant is Object:
				valid_rules.append(rule_variant)
			continue

		errors_by_index[index] = filtered_errors.duplicate()
		var rule_id: StringName = _extract_rule_id(rule_variant, index)
		errors_by_rule_id[rule_id] = filtered_errors.duplicate()

	return {
		"valid_rules": valid_rules,
		"errors_by_index": errors_by_index,
		"errors_by_rule_id": errors_by_rule_id,
		"warnings_by_index": warnings_by_index,
		"warnings_by_rule_id": warnings_by_rule_id,
	}

func _extract_rule_id(rule_variant: Variant, index: int) -> StringName:
	var rule_id: StringName = U_RuleUtils.read_string_name_property(rule_variant, "rule_id")
	if rule_id != StringName():
		return rule_id
	return StringName("__index_%d" % index)

func _is_ignorable_validation_error(error_text: String) -> bool:
	if IGNORABLE_VALIDATION_ERRORS_EXACT.has(error_text):
		return true
	if error_text.ends_with("must be RS_BaseCondition"):
		return true
	if error_text.ends_with("must be RS_BaseEffect"):
		return true
	return false
