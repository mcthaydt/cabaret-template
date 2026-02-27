@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_GameEventSystem

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_RULE_SELECTOR := preload("res://scripts/utils/qb/u_rule_selector.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_RULE_VALIDATOR := preload("res://scripts/utils/qb/u_rule_validator.gd")
const EFFECT_PUBLISH_EVENT_SCRIPT := preload("res://scripts/resources/qb/effects/rs_effect_publish_event.gd")
const CONDITION_EVENT_NAME_SCRIPT := preload("res://scripts/resources/qb/conditions/rs_condition_event_name.gd")

const TRIGGER_MODE_TICK := "tick"
const TRIGGER_MODE_EVENT := "event"
const TRIGGER_MODE_BOTH := "both"

const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/game/cfg_checkpoint_rule.tres"),
	preload("res://resources/qb/game/cfg_victory_rule.tres"),
]

@export var state_store: I_StateStore = null
@export var rules: Array[Resource] = []

var _tracker: U_RuleStateTracker = RULE_STATE_TRACKER.new()
var _active_rules: Array = []
var _rule_validation_report: Dictionary = {}
var _event_unsubscribers: Array[Callable] = []
var _has_tick_rules: bool = false

func on_configured() -> void:
	_refresh_active_rules()
	_subscribe_rule_events()

func _exit_tree() -> void:
	_unsubscribe_rule_events()

func process_tick(delta: float) -> void:
	_tracker.tick_cooldowns(delta)
	if not _has_tick_rules:
		return

	var context: Dictionary = _build_tick_context()
	_evaluate_context(context, TRIGGER_MODE_TICK, StringName())
	_tracker.cleanup_stale_contexts([_context_key_for_context(context)])

func get_rule_validation_report() -> Dictionary:
	return _rule_validation_report.duplicate(true)

func _refresh_active_rules() -> void:
	var combined_rules: Array = DEFAULT_RULE_DEFINITIONS.duplicate()
	for rule_variant in rules:
		combined_rules.append(rule_variant)

	_rule_validation_report = U_RULE_VALIDATOR.validate_rules(combined_rules)
	var valid_rules_variant: Variant = _rule_validation_report.get("valid_rules", [])
	if valid_rules_variant is Array:
		_active_rules = (valid_rules_variant as Array).duplicate()
	else:
		_active_rules = []

	_has_tick_rules = false
	for rule_variant in _active_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue
		var trigger_mode: String = _read_string_property(rule_variant, "trigger_mode", TRIGGER_MODE_TICK)
		if trigger_mode == TRIGGER_MODE_TICK or trigger_mode == TRIGGER_MODE_BOTH:
			_has_tick_rules = true
			break

func _subscribe_rule_events() -> void:
	_unsubscribe_rule_events()
	var subscribed_events: Dictionary = {}

	for rule_variant in _active_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue

		var trigger_mode: String = _read_string_property(rule_variant, "trigger_mode", TRIGGER_MODE_TICK)
		if trigger_mode != TRIGGER_MODE_EVENT and trigger_mode != TRIGGER_MODE_BOTH:
			continue

		var event_names: Array[StringName] = _extract_event_names_from_rule(rule_variant)
		for event_name in event_names:
			if event_name == StringName() or subscribed_events.has(event_name):
				continue

			var unsubscribe: Callable = U_ECS_EVENT_BUS.subscribe(event_name, func(event_data: Dictionary) -> void:
				_on_event_received(event_name, event_data)
			)
			if unsubscribe.is_valid():
				_event_unsubscribers.append(unsubscribe)
				subscribed_events[event_name] = true

func _unsubscribe_rule_events() -> void:
	for unsubscribe in _event_unsubscribers:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribers.clear()

func _on_event_received(event_name: StringName, event_data: Dictionary) -> void:
	_tracker.tick_cooldowns(0.0)

	var event_payload: Dictionary = _extract_event_payload(event_data)
	var context: Dictionary = _build_event_context(event_name, event_payload)
	_evaluate_context(context, TRIGGER_MODE_EVENT, event_name)
	_tracker.cleanup_stale_contexts([_context_key_for_context(context)])

func _evaluate_context(context: Dictionary, trigger_mode: String, _event_name: StringName) -> void:
	var applicable_rules: Array = _get_applicable_rules(trigger_mode)
	if applicable_rules.is_empty():
		return

	var scored: Array[Dictionary] = U_RULE_SCORER.score_rules(applicable_rules, context)
	if scored.is_empty():
		return

	var gated: Array[Dictionary] = _apply_state_gates(applicable_rules, scored, context)
	if gated.is_empty():
		return

	var winners: Array[Dictionary] = U_RULE_SELECTOR.select_winners(gated)
	if winners.is_empty():
		return

	_execute_effects(winners, context)
	_mark_fired_rules(winners, context)

func _get_applicable_rules(trigger_mode: String) -> Array:
	var applicable_rules: Array = []
	for rule_variant in _active_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue

		var rule_trigger_mode: String = _read_string_property(rule_variant, "trigger_mode", TRIGGER_MODE_TICK)
		if trigger_mode == TRIGGER_MODE_TICK:
			if rule_trigger_mode == TRIGGER_MODE_TICK or rule_trigger_mode == TRIGGER_MODE_BOTH:
				applicable_rules.append(rule_variant)
			continue

		if trigger_mode == TRIGGER_MODE_EVENT:
			if rule_trigger_mode != TRIGGER_MODE_EVENT and rule_trigger_mode != TRIGGER_MODE_BOTH:
				continue
			applicable_rules.append(rule_variant)

	return applicable_rules

func _apply_state_gates(applicable_rules: Array, scored: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var context_key: StringName = _context_key_for_context(context)

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
			gated.append(result_variant)

	return gated

func _execute_effects(winners: Array[Dictionary], context: Dictionary) -> void:
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
			if _is_publish_event_effect(effect_variant):
				_execute_publish_event_effect(effect_variant, context)
				continue
			if not effect_variant is I_Effect:
				continue
			effect_variant.call("execute", context)

func _execute_publish_event_effect(effect_variant: Variant, context: Dictionary) -> void:
	if effect_variant == null or not (effect_variant is Object):
		return

	var event_name: StringName = _read_string_name_property(effect_variant, "event_name")
	if event_name == StringName():
		return

	var payload: Dictionary = {}
	var event_payload_variant: Variant = context.get("event_payload", {})
	if event_payload_variant is Dictionary:
		payload = (event_payload_variant as Dictionary).duplicate(true)

	var configured_payload_variant: Variant = effect_variant.get("payload")
	if configured_payload_variant is Dictionary:
		payload.merge((configured_payload_variant as Dictionary).duplicate(true), true)

	var inject_entity_id: bool = _read_bool_property(effect_variant, "inject_entity_id", true)
	var entity_id: Variant = _get_context_value(context, "entity_id")
	if inject_entity_id and entity_id != null and not payload.has("entity_id"):
		payload["entity_id"] = entity_id

	U_ECS_EVENT_BUS.publish(event_name, payload)

func _mark_fired_rules(winners: Array[Dictionary], context: Dictionary) -> void:
	var context_key: StringName = _context_key_for_context(context)
	for winner in winners:
		var rule_variant: Variant = winner.get("rule", null)
		if rule_variant == null or not (rule_variant is Object):
			continue

		var rule_id: StringName = _resolve_rule_id(rule_variant)
		var cooldown: float = maxf(_read_float_property(rule_variant, "cooldown", 0.0), 0.0)
		_tracker.mark_fired(rule_id, context_key, cooldown)

		if _read_bool_property(rule_variant, "one_shot", false):
			_tracker.mark_one_shot_spent(rule_id)

func _build_tick_context() -> Dictionary:
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = {}
	if store != null:
		redux_state = store.get_state()

	var context: Dictionary = {
		"redux_state": redux_state.duplicate(true),
	}
	context["state"] = context["redux_state"]
	if store != null:
		context["state_store"] = store

	return context

func _build_event_context(event_name: StringName, event_payload: Dictionary) -> Dictionary:
	var context: Dictionary = _build_tick_context()
	context["event_name"] = event_name
	context["event_payload"] = event_payload.duplicate(true)

	var entity_id: Variant = _extract_entity_id(event_payload)
	if entity_id != null:
		context["entity_id"] = entity_id

	_attach_entity_context(context)
	return context

func _attach_entity_context(context: Dictionary) -> void:
	var entity_id_variant: Variant = _get_context_value(context, "entity_id")
	if entity_id_variant == null:
		return

	var entity_id: StringName = _variant_to_string_name(entity_id_variant)
	if entity_id == StringName():
		return

	var manager: I_ECSManager = get_manager()
	if manager == null:
		return

	var entity: Node = manager.get_entity_by_id(entity_id)
	if entity == null:
		return

	context["entity"] = entity
	if entity.has_method("get_tags"):
		var tags_variant: Variant = entity.call("get_tags")
		if tags_variant is Array:
			context["entity_tags"] = tags_variant

	var components: Dictionary = manager.get_components_for_entity(entity)
	if components.is_empty():
		return

	context["components"] = components.duplicate(true)
	context["component_data"] = context["components"]

func _extract_event_payload(event_data: Dictionary) -> Dictionary:
	var payload_variant: Variant = event_data.get("payload", {})
	if payload_variant is Dictionary:
		return (payload_variant as Dictionary).duplicate(true)
	return {}

func _extract_entity_id(event_payload: Dictionary) -> Variant:
	if event_payload.has("entity_id"):
		return event_payload.get("entity_id")

	var entity_key: StringName = StringName("entity_id")
	if event_payload.has(entity_key):
		return event_payload.get(entity_key)

	return null

func _context_key_for_context(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = _get_context_value(context, "entity_id")
	var entity_id: StringName = _variant_to_string_name(entity_id_variant)
	if entity_id != StringName():
		return entity_id
	return StringName()

func _resolve_rule_id(rule_variant: Variant) -> StringName:
	var rule_id: StringName = _read_string_name_property(rule_variant, "rule_id")
	if rule_id != StringName():
		return rule_id
	if rule_variant is Object:
		return StringName("__rule_%d" % (rule_variant as Object).get_instance_id())
	return StringName("__rule")

func _extract_event_names_from_rule(rule_variant: Variant) -> Array[StringName]:
	var event_names: Array[StringName] = []
	if rule_variant == null or not (rule_variant is Object):
		return event_names

	var conditions_variant: Variant = (rule_variant as Object).get("conditions")
	if not (conditions_variant is Array):
		return event_names

	for condition_variant in conditions_variant as Array:
		var condition_event_name: StringName = _extract_event_name_from_condition(condition_variant)
		if condition_event_name == StringName():
			continue
		if event_names.has(condition_event_name):
			continue
		event_names.append(condition_event_name)

	return event_names

func _extract_event_name_from_condition(condition_variant: Variant) -> StringName:
	if condition_variant == null or not (condition_variant is Object):
		return StringName()
	var condition_object: Object = condition_variant as Object
	if not _is_script_instance_of(condition_object, CONDITION_EVENT_NAME_SCRIPT):
		return StringName()
	return _read_string_name_property(condition_object, "expected_event_name")

func _resolve_store() -> I_StateStore:
	if state_store != null:
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _is_publish_event_effect(effect_variant: Variant) -> bool:
	if effect_variant == null or not (effect_variant is Object):
		return false
	return _is_script_instance_of(effect_variant as Object, EFFECT_PUBLISH_EVENT_SCRIPT)

func _is_script_instance_of(object_value: Object, script_ref: Script) -> bool:
	if object_value == null:
		return false
	if script_ref == null:
		return false

	var current: Variant = object_value.get_script()
	while current != null and current is Script:
		if current == script_ref:
			return true
		current = (current as Script).get_base_script()
	return false

func _get_context_value(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null

func _variant_to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		var text: String = value
		if not text.is_empty():
			return StringName(text)
	return StringName()

func _read_string_property(object_value: Variant, property_name: String, fallback: String = "") -> String:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

func _read_string_name_property(object_value: Variant, property_name: String) -> StringName:
	if object_value == null or not (object_value is Object):
		return StringName()
	var value: Variant = object_value.get(property_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName()

func _read_bool_property(object_value: Variant, property_name: String, fallback: bool = false) -> bool:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is bool:
		return value
	return fallback

func _read_float_property(object_value: Variant, property_name: String, fallback: float = 0.0) -> float:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback
