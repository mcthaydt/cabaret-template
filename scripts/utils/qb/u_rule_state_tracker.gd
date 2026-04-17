extends RefCounted
class_name U_RuleStateTracker

const GLOBAL_CONTEXT_KEY := StringName("__global__")

var _cooldowns_by_rule: Dictionary = {}
var _was_true_by_rule: Dictionary = {}
var _one_shot_spent_by_rule: Dictionary = {}

func tick_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return
	if _cooldowns_by_rule.is_empty():
		return

	for rule_key_variant in _cooldowns_by_rule.keys():
		var context_map_variant: Variant = _cooldowns_by_rule.get(rule_key_variant, {})
		if not (context_map_variant is Dictionary):
			continue
		var context_map: Dictionary = context_map_variant as Dictionary
		var context_keys: Array = context_map.keys()
		for context_key_variant in context_keys:
			var remaining: float = float(context_map.get(context_key_variant, 0.0))
			remaining = maxf(remaining - delta, 0.0)
			if remaining <= 0.0:
				context_map.erase(context_key_variant)
			else:
				context_map[context_key_variant] = remaining

		if context_map.is_empty():
			_cooldowns_by_rule.erase(rule_key_variant)
		else:
			_cooldowns_by_rule[rule_key_variant] = context_map

func is_on_cooldown(rule_id: StringName, context_key: Variant = null) -> bool:
	return get_cooldown_remaining(rule_id, context_key) > 0.0

func get_cooldown_remaining(rule_id: StringName, context_key: Variant = null) -> float:
	var normalized_context: StringName = _normalize_context_key(context_key)
	var context_map: Dictionary = _get_rule_context_map(_cooldowns_by_rule, rule_id)
	return float(context_map.get(normalized_context, 0.0))

func mark_fired(rule_id: StringName, context_key: Variant = null, cooldown_duration: float = 0.0) -> void:
	if cooldown_duration <= 0.0:
		return

	var normalized_context: StringName = _normalize_context_key(context_key)
	var context_map: Dictionary = _get_or_create_rule_context_map(_cooldowns_by_rule, rule_id)
	context_map[normalized_context] = cooldown_duration
	_cooldowns_by_rule[rule_id] = context_map

func check_rising_edge(rule_id: StringName, context_key: Variant, is_passing_now: bool) -> bool:
	var normalized_context: StringName = _normalize_context_key(context_key)
	var context_map: Dictionary = _get_or_create_rule_context_map(_was_true_by_rule, rule_id)
	var was_true_before: bool = bool(context_map.get(normalized_context, false))
	context_map[normalized_context] = is_passing_now
	_was_true_by_rule[rule_id] = context_map
	return is_passing_now and not was_true_before

func has_rising_edge_state(rule_id: StringName, context_key: Variant) -> bool:
	var normalized_context: StringName = _normalize_context_key(context_key)
	var context_map: Dictionary = _get_rule_context_map(_was_true_by_rule, rule_id)
	return context_map.has(normalized_context)

func mark_one_shot_spent(rule_id: StringName, context_key: Variant = null) -> void:
	var normalized_context: StringName = _normalize_context_key(context_key)
	var context_map: Dictionary = _get_or_create_rule_context_map(_one_shot_spent_by_rule, rule_id)
	context_map[normalized_context] = true
	_one_shot_spent_by_rule[rule_id] = context_map

func is_one_shot_spent(rule_id: StringName, context_key: Variant = null) -> bool:
	var normalized_context: StringName = _normalize_context_key(context_key)
	var context_map: Dictionary = _get_rule_context_map(_one_shot_spent_by_rule, rule_id)
	return bool(context_map.get(normalized_context, false))

func cleanup_stale_contexts(active_context_keys: Array) -> void:
	var active_context_lookup: Dictionary = {}
	for key_variant in active_context_keys:
		active_context_lookup[_normalize_context_key(key_variant)] = true

	_cleanup_cooldown_contexts(active_context_lookup)
	_cleanup_rising_edge_contexts(active_context_lookup)

func _cleanup_cooldown_contexts(active_lookup: Dictionary) -> void:
	for rule_key_variant in _cooldowns_by_rule.keys():
		var context_map_variant: Variant = _cooldowns_by_rule.get(rule_key_variant, {})
		if not (context_map_variant is Dictionary):
			continue
		var context_map: Dictionary = context_map_variant as Dictionary
		var context_keys: Array = context_map.keys()
		for context_key_variant in context_keys:
			var context_key: StringName = _normalize_context_key(context_key_variant)
			if active_lookup.has(context_key):
				continue
			var remaining: float = float(context_map.get(context_key_variant, 0.0))
			if remaining <= 0.0:
				context_map.erase(context_key_variant)

		if context_map.is_empty():
			_cooldowns_by_rule.erase(rule_key_variant)
		else:
			_cooldowns_by_rule[rule_key_variant] = context_map

func _cleanup_rising_edge_contexts(active_lookup: Dictionary) -> void:
	for rule_key_variant in _was_true_by_rule.keys():
		var context_map_variant: Variant = _was_true_by_rule.get(rule_key_variant, {})
		if not (context_map_variant is Dictionary):
			continue
		var context_map: Dictionary = context_map_variant as Dictionary
		var context_keys: Array = context_map.keys()
		for context_key_variant in context_keys:
			var context_key: StringName = _normalize_context_key(context_key_variant)
			if not active_lookup.has(context_key):
				context_map.erase(context_key_variant)

		if context_map.is_empty():
			_was_true_by_rule.erase(rule_key_variant)
		else:
			_was_true_by_rule[rule_key_variant] = context_map

func _get_rule_context_map(source: Dictionary, rule_id: StringName) -> Dictionary:
	var context_map_variant: Variant = source.get(rule_id, {})
	if context_map_variant is Dictionary:
		return context_map_variant as Dictionary
	return {}

func _get_or_create_rule_context_map(source: Dictionary, rule_id: StringName) -> Dictionary:
	var context_map_variant: Variant = source.get(rule_id, null)
	if context_map_variant is Dictionary:
		return context_map_variant as Dictionary
	return {}

func _normalize_context_key(context_key: Variant) -> StringName:
	if context_key == null:
		return GLOBAL_CONTEXT_KEY
	if context_key is StringName:
		var value: StringName = context_key
		return value if value != StringName() else GLOBAL_CONTEXT_KEY
	if context_key is String:
		var text: String = context_key
		return StringName(text) if not text.is_empty() else GLOBAL_CONTEXT_KEY
	return StringName(str(context_key))
