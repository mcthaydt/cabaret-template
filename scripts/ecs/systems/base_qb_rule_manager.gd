@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name BaseQBRuleManager

const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_QB_RULE_EVALUATOR := preload("res://scripts/utils/qb/u_qb_rule_evaluator.gd")
const U_QB_QUALITY_PROVIDER := preload("res://scripts/utils/qb/u_qb_quality_provider.gd")
const U_QB_EFFECT_EXECUTOR := preload("res://scripts/utils/qb/u_qb_effect_executor.gd")
const U_QB_RULE_VALIDATOR := preload("res://scripts/utils/qb/u_qb_rule_validator.gd")
const U_QB_VARIANT_UTILS := preload("res://scripts/utils/qb/u_qb_variant_utils.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")

const GLOBAL_CONTEXT_KEY := "__global__"

@export var state_store: I_StateStore = null
@export var rule_definitions: Array = []

var _registered_rules: Array = []
var _rule_states: Dictionary = {}
var _event_rule_ids: Dictionary = {}
var _event_unsubscribers: Dictionary = {}
var _rule_validation_report: Dictionary = {}

func _init() -> void:
	execution_priority = -1

func on_configured() -> void:
	_unregister_event_subscriptions()
	_rule_validation_report = U_QB_RULE_VALIDATOR.validate_rule_definitions(_resolve_rule_definitions())
	_warn_invalid_rule_definitions()
	_register_rules(_get_valid_rule_definitions())
	_register_event_subscriptions()

func _exit_tree() -> void:
	_unregister_event_subscriptions()

func process_tick(delta: float) -> void:
	_tick_cooldowns(delta)
	_begin_tick_context_tracking()
	var contexts: Array = _get_tick_contexts(delta)
	_evaluate_contexts(contexts, QB_RULE.TriggerMode.TICK)
	_post_tick_evaluation(contexts, delta)
	_cleanup_stale_context_state()

func get_default_rule_definitions() -> Array:
	return []

func _get_tick_contexts(_delta: float) -> Array:
	return []

func _post_tick_evaluation(_contexts: Array, _delta: float) -> void:
	pass

func get_registered_rule_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule_variant in _registered_rules:
		var rule_id: StringName = _get_rule_id(rule_variant)
		if rule_id == &"":
			continue
		ids.append(rule_id)
	return ids

func get_rule_runtime_state(rule_id: StringName) -> Dictionary:
	var state_variant: Variant = _rule_states.get(rule_id, null)
	if not (state_variant is Dictionary):
		return {}
	return (state_variant as Dictionary).duplicate(true)

func get_rule_validation_report() -> Dictionary:
	return _rule_validation_report.duplicate(true)

func _build_event_context(event_name: StringName, event_payload: Dictionary) -> Dictionary:
	var context: Dictionary = {
		"event_name": event_name,
		"event_payload": event_payload.duplicate(true),
	}
	if event_payload.has("entity_id"):
		context["entity_id"] = event_payload.get("entity_id")
	return context

func _resolve_rule_definitions() -> Array:
	if not rule_definitions.is_empty():
		return rule_definitions
	return get_default_rule_definitions()

func _get_valid_rule_definitions() -> Array:
	var valid_rules_variant: Variant = _rule_validation_report.get("valid_rules", [])
	if valid_rules_variant is Array:
		return (valid_rules_variant as Array).duplicate()
	return []

func _warn_invalid_rule_definitions() -> void:
	if not _should_emit_rule_validation_warnings():
		return

	var errors_variant: Variant = _rule_validation_report.get("errors_by_rule_id", {})
	if not (errors_variant is Dictionary):
		return
	var errors_by_rule_id: Dictionary = errors_variant as Dictionary
	if errors_by_rule_id.is_empty():
		return

	var rule_keys: Array[String] = []
	for key_variant in errors_by_rule_id.keys():
		rule_keys.append(String(key_variant))
	rule_keys.sort()

	for rule_key in rule_keys:
		var errors: Array[String] = _resolve_rule_errors(errors_by_rule_id, rule_key)
		for error in errors:
			_emit_rule_validation_warning(
				"BaseQBRuleManager: Invalid rule '%s': %s" % [rule_key, error]
			)

func _resolve_rule_errors(errors_by_rule_id: Dictionary, rule_key: String) -> Array[String]:
	var lookup_key: Variant = rule_key
	if not errors_by_rule_id.has(lookup_key):
		lookup_key = StringName(rule_key)
	var errors_variant: Variant = errors_by_rule_id.get(lookup_key, [])
	if not (errors_variant is Array):
		return []

	var typed_errors: Array[String] = []
	for error_variant in errors_variant:
		typed_errors.append(str(error_variant))
	return typed_errors

func _should_emit_rule_validation_warnings() -> bool:
	return Engine.is_editor_hint()

func _emit_rule_validation_warning(message: String) -> void:
	push_warning(message)

func _register_rules(definitions: Array) -> void:
	_registered_rules.clear()
	_rule_states.clear()
	_event_rule_ids.clear()

	var valid_rules: Array = []
	for rule_variant in definitions:
		if rule_variant == null or not (rule_variant is Object):
			continue
		var rule_id: StringName = _get_rule_id(rule_variant)
		if rule_id == &"":
			push_warning("BaseQBRuleManager: Skipping rule with empty rule_id.")
			continue
		if _rule_states.has(rule_id):
			push_warning("BaseQBRuleManager: Duplicate rule_id '%s' skipped." % String(rule_id))
			continue
		valid_rules.append(rule_variant)
		_rule_states[rule_id] = _create_rule_state()

	_registered_rules = _sort_rules(valid_rules)
	_rebuild_event_rule_map()

func _create_rule_state() -> Dictionary:
	return {
		"is_active": true,
		"has_fired": false,
		"cooldown_remaining": 0.0,
		"context_cooldowns": {},
		"was_true_by_context": {},
		"active_cooldown_keys": {},
		"active_salience_keys": {},
	}

func _sort_rules(rules: Array) -> Array:
	var sorted_rules: Array = rules.duplicate()
	sorted_rules.sort_custom(func(a: Variant, b: Variant) -> bool:
		var priority_a: int = _get_int_property(a, "priority", 0)
		var priority_b: int = _get_int_property(b, "priority", 0)
		if priority_a != priority_b:
			return priority_a > priority_b
		var rule_id_a: String = String(_get_rule_id(a))
		var rule_id_b: String = String(_get_rule_id(b))
		return rule_id_a < rule_id_b
	)
	return sorted_rules

func _rebuild_event_rule_map() -> void:
	_event_rule_ids.clear()
	for rule_variant in _registered_rules:
		var trigger_mode: int = _get_int_property(rule_variant, "trigger_mode", QB_RULE.TriggerMode.TICK)
		if trigger_mode != QB_RULE.TriggerMode.EVENT and trigger_mode != QB_RULE.TriggerMode.BOTH:
			continue
		var trigger_event: StringName = StringName(_get_string_property(rule_variant, "trigger_event", ""))
		if trigger_event == &"":
			continue
		if not _event_rule_ids.has(trigger_event):
			_event_rule_ids[trigger_event] = []
		var rule_ids: Array = _event_rule_ids[trigger_event]
		rule_ids.append(_get_rule_id(rule_variant))

func _register_event_subscriptions() -> void:
	for event_name_variant in _event_rule_ids.keys():
		var event_name: StringName = StringName(event_name_variant)
		if event_name == &"":
			continue
		var event_name_copy: StringName = event_name
		var unsubscribe := U_ECS_EVENT_BUS.subscribe(event_name_copy, func(event_data: Dictionary) -> void:
			_on_event_received(event_name_copy, event_data)
		)
		_event_unsubscribers[event_name_copy] = unsubscribe

func _unregister_event_subscriptions() -> void:
	for unsubscribe_variant in _event_unsubscribers.values():
		if not (unsubscribe_variant is Callable):
			continue
		var unsubscribe: Callable = unsubscribe_variant
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribers.clear()

func _on_event_received(event_name: StringName, event_data: Dictionary) -> void:
	var payload: Dictionary = {}
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		payload = (event_data["payload"] as Dictionary).duplicate(true)
	elif event_data is Dictionary:
		payload = event_data.duplicate(true)

	var context: Dictionary = _build_event_context(event_name, payload)
	_ensure_context_dependencies(context)
	_evaluate_rules_for_context(context, QB_RULE.TriggerMode.EVENT, event_name)

func _evaluate_contexts(contexts: Array, evaluation_mode: int, event_name: StringName = StringName()) -> void:
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant
		_ensure_context_dependencies(context)
		_evaluate_rules_for_context(context, evaluation_mode, event_name)

func _evaluate_rules_for_context(context: Dictionary, evaluation_mode: int, event_name: StringName = StringName()) -> void:
	for rule_variant in _registered_rules:
		if not _rule_matches_evaluation(rule_variant, evaluation_mode, event_name):
			continue

		var rule_id: StringName = _get_rule_id(rule_variant)
		var state_variant: Variant = _rule_states.get(rule_id, null)
		if not (state_variant is Dictionary):
			continue
		var rule_state: Dictionary = state_variant as Dictionary
		if not bool(rule_state.get("is_active", true)):
			continue

		var cooldown_key: String = _resolve_cooldown_key(rule_variant, context)
		var salience_key: String = _resolve_salience_key(context)
		if evaluation_mode == QB_RULE.TriggerMode.TICK:
			_mark_active_context_keys(rule_state, cooldown_key, salience_key)

		var is_true_now: bool = _evaluate_rule_conditions(rule_variant, context)
		var was_true_map_variant: Variant = rule_state.get("was_true_by_context", {})
		var was_true_map: Dictionary = was_true_map_variant if was_true_map_variant is Dictionary else {}
		var was_true_before: bool = bool(was_true_map.get(salience_key, false))
		was_true_map[salience_key] = is_true_now
		rule_state["was_true_by_context"] = was_true_map
		_rule_states[rule_id] = rule_state

		if not is_true_now:
			continue

		var requires_salience: bool = _requires_salience(rule_variant, evaluation_mode)
		if requires_salience and was_true_before:
			continue

		if not _is_cooldown_ready(rule_variant, rule_state, context, cooldown_key):
			continue

		U_QB_EFFECT_EXECUTOR.execute_effects(_get_array_property(rule_variant, "effects"), context)
		_set_cooldown(rule_variant, rule_state, context, cooldown_key)

		if bool(_get_bool_property(rule_variant, "is_one_shot", false)):
			rule_state["is_active"] = false
			rule_state["has_fired"] = true
			_rule_states[rule_id] = rule_state

func _rule_matches_evaluation(rule: Variant, evaluation_mode: int, event_name: StringName) -> bool:
	var trigger_mode: int = _get_int_property(rule, "trigger_mode", QB_RULE.TriggerMode.TICK)
	if evaluation_mode == QB_RULE.TriggerMode.TICK:
		return trigger_mode == QB_RULE.TriggerMode.TICK or trigger_mode == QB_RULE.TriggerMode.BOTH

	if evaluation_mode == QB_RULE.TriggerMode.EVENT:
		if trigger_mode != QB_RULE.TriggerMode.EVENT and trigger_mode != QB_RULE.TriggerMode.BOTH:
			return false
		var trigger_event: StringName = StringName(_get_string_property(rule, "trigger_event", ""))
		return trigger_event == event_name

	return false

func _evaluate_rule_conditions(rule: Variant, context: Dictionary) -> bool:
	var conditions: Array = _get_array_property(rule, "conditions")
	if conditions.is_empty():
		return true

	for condition_variant in conditions:
		var quality_value: Variant = U_QB_QUALITY_PROVIDER.read_quality(condition_variant, context)
		if not U_QB_RULE_EVALUATOR.evaluate_condition(condition_variant, quality_value):
			return false
	return true

func _requires_salience(rule: Variant, evaluation_mode: int) -> bool:
	if evaluation_mode == QB_RULE.TriggerMode.EVENT:
		var trigger_mode: int = _get_int_property(rule, "trigger_mode", QB_RULE.TriggerMode.TICK)
		if trigger_mode == QB_RULE.TriggerMode.EVENT:
			return false
	return _get_bool_property(rule, "requires_salience", true)

func _is_cooldown_ready(rule: Variant, rule_state: Dictionary, context: Dictionary, cooldown_key: String) -> bool:
	var cooldown_keys: Array = _get_array_property(rule, "cooldown_key_fields")
	if cooldown_keys.is_empty():
		return float(rule_state.get("cooldown_remaining", 0.0)) <= 0.0

	var cooldowns_variant: Variant = rule_state.get("context_cooldowns", {})
	var cooldowns: Dictionary = cooldowns_variant if cooldowns_variant is Dictionary else {}
	return float(cooldowns.get(cooldown_key, 0.0)) <= 0.0

func _set_cooldown(rule: Variant, rule_state: Dictionary, context: Dictionary, cooldown_key: String) -> void:
	var duration: float = _resolve_cooldown_duration(rule, context)
	if duration <= 0.0:
		return

	var cooldown_keys: Array = _get_array_property(rule, "cooldown_key_fields")
	if cooldown_keys.is_empty():
		rule_state["cooldown_remaining"] = duration
	else:
		var cooldowns_variant: Variant = rule_state.get("context_cooldowns", {})
		var cooldowns: Dictionary = cooldowns_variant if cooldowns_variant is Dictionary else {}
		cooldowns[cooldown_key] = duration
		rule_state["context_cooldowns"] = cooldowns

	var rule_id: StringName = _get_rule_id(rule)
	_rule_states[rule_id] = rule_state

func _resolve_cooldown_duration(rule: Variant, context: Dictionary) -> float:
	var base_cooldown: float = maxf(_get_float_property(rule, "cooldown", 0.0), 0.0)
	var override_field: String = _get_string_property(rule, "cooldown_from_context_field", "")
	if override_field.is_empty():
		return base_cooldown

	var override_value: Variant = _resolve_context_path(context, override_field)
	if override_value is float or override_value is int:
		return maxf(float(override_value), 0.0)
	return base_cooldown

func _resolve_cooldown_key(rule: Variant, context: Dictionary) -> String:
	var cooldown_keys: Array = _get_array_property(rule, "cooldown_key_fields")
	if cooldown_keys.is_empty():
		return GLOBAL_CONTEXT_KEY

	var resolved: Array[String] = []
	for key_variant in cooldown_keys:
		var key: String = String(key_variant)
		var value: Variant = _resolve_context_path(context, key)
		if value == null:
			resolved.append("<missing>")
		else:
			resolved.append(str(value))
	return "|".join(resolved)

func _resolve_salience_key(context: Dictionary) -> String:
	var entity_id: Variant = context.get("entity_id", null)
	if entity_id == null:
		return GLOBAL_CONTEXT_KEY
	return str(entity_id)

func _mark_active_context_keys(rule_state: Dictionary, cooldown_key: String, salience_key: String) -> void:
	var active_cooldown_variant: Variant = rule_state.get("active_cooldown_keys", {})
	var active_cooldown: Dictionary = active_cooldown_variant if active_cooldown_variant is Dictionary else {}
	active_cooldown[cooldown_key] = true
	rule_state["active_cooldown_keys"] = active_cooldown

	var active_salience_variant: Variant = rule_state.get("active_salience_keys", {})
	var active_salience: Dictionary = active_salience_variant if active_salience_variant is Dictionary else {}
	active_salience[salience_key] = true
	rule_state["active_salience_keys"] = active_salience

func _begin_tick_context_tracking() -> void:
	for rule_id_variant in _rule_states.keys():
		var rule_id: StringName = StringName(rule_id_variant)
		var state_variant: Variant = _rule_states.get(rule_id, {})
		if not (state_variant is Dictionary):
			continue
		var state: Dictionary = state_variant
		state["active_cooldown_keys"] = {}
		state["active_salience_keys"] = {}
		_rule_states[rule_id] = state

func _cleanup_stale_context_state() -> void:
	for rule_id_variant in _rule_states.keys():
		var rule_id: StringName = StringName(rule_id_variant)
		var state_variant: Variant = _rule_states.get(rule_id, {})
		if not (state_variant is Dictionary):
			continue
		var state: Dictionary = state_variant

		var active_cooldown: Dictionary = state.get("active_cooldown_keys", {})
		var active_salience: Dictionary = state.get("active_salience_keys", {})

		var cooldowns_variant: Variant = state.get("context_cooldowns", {})
		var cooldowns: Dictionary = cooldowns_variant if cooldowns_variant is Dictionary else {}
		_remove_stale_keys(cooldowns, active_cooldown)
		state["context_cooldowns"] = cooldowns

		var salience_variant: Variant = state.get("was_true_by_context", {})
		var salience_map: Dictionary = salience_variant if salience_variant is Dictionary else {}
		_remove_stale_keys(salience_map, active_salience)
		state["was_true_by_context"] = salience_map

		state["active_cooldown_keys"] = {}
		state["active_salience_keys"] = {}
		_rule_states[rule_id] = state

func _remove_stale_keys(values: Dictionary, active_keys: Dictionary) -> void:
	var keys: Array = values.keys()
	for key_variant in keys:
		var key: String = String(key_variant)
		if key == GLOBAL_CONTEXT_KEY:
			continue
		if active_keys.has(key):
			continue
		values.erase(key)

func _tick_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return

	for rule_id_variant in _rule_states.keys():
		var rule_id: StringName = StringName(rule_id_variant)
		var state_variant: Variant = _rule_states.get(rule_id, null)
		if not (state_variant is Dictionary):
			continue

		var state: Dictionary = state_variant
		var cooldown_remaining: float = maxf(float(state.get("cooldown_remaining", 0.0)) - delta, 0.0)
		state["cooldown_remaining"] = cooldown_remaining

		var cooldowns_variant: Variant = state.get("context_cooldowns", {})
		var cooldowns: Dictionary = cooldowns_variant if cooldowns_variant is Dictionary else {}
		var keys: Array = cooldowns.keys()
		for key_variant in keys:
			var key: String = String(key_variant)
			var remaining: float = maxf(float(cooldowns.get(key, 0.0)) - delta, 0.0)
			cooldowns[key] = remaining
		state["context_cooldowns"] = cooldowns

		_rule_states[rule_id] = state

func _ensure_context_dependencies(context: Dictionary) -> void:
	if not context.has("state_store"):
		var store: I_StateStore = _resolve_store()
		if store != null:
			context["state_store"] = store

func _resolve_store() -> I_StateStore:
	if state_store != null:
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _resolve_context_path(context: Dictionary, path: String) -> Variant:
	if path.is_empty():
		return null
	if context.has(path):
		return context.get(path)

	var current: Variant = context
	var segments: PackedStringArray = path.split(".")
	for segment in segments:
		if not (current is Dictionary):
			return null
		var current_dict: Dictionary = current
		if current_dict.has(segment):
			current = current_dict.get(segment)
			continue
		var segment_name: StringName = StringName(segment)
		if current_dict.has(segment_name):
			current = current_dict.get(segment_name)
			continue
		return null
	return current

func _get_rule_id(rule: Variant) -> StringName:
	var value: Variant = rule.get("rule_id")
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""

func _get_array_property(object_value: Variant, property_name: String) -> Array:
	return U_QB_VARIANT_UTILS.get_array_property(object_value, property_name)

func _get_bool_property(object_value: Variant, property_name: String, fallback: bool) -> bool:
	return U_QB_VARIANT_UTILS.get_bool_property(object_value, property_name, fallback)

func _get_int_property(object_value: Variant, property_name: String, fallback: int) -> int:
	return U_QB_VARIANT_UTILS.get_int_property(object_value, property_name, fallback)

func _get_float_property(object_value: Variant, property_name: String, fallback: float) -> float:
	return U_QB_VARIANT_UTILS.get_float_property(object_value, property_name, fallback)

func _get_string_property(object_value: Variant, property_name: String, fallback: String) -> String:
	return U_QB_VARIANT_UTILS.get_string_property(object_value, property_name, fallback)
