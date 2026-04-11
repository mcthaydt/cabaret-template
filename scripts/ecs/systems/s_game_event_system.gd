@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_GameEventSystem

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_RULE_EVALUATOR := preload("res://scripts/utils/ecs/u_rule_evaluator.gd")
const EFFECT_PUBLISH_EVENT_SCRIPT := preload("res://scripts/resources/qb/effects/rs_effect_publish_event.gd")
const CONDITION_EVENT_NAME_SCRIPT := preload("res://scripts/resources/qb/conditions/rs_condition_event_name.gd")
const CONDITION_COMPOSITE_SCRIPT := preload("res://scripts/resources/qb/conditions/rs_condition_composite.gd")

const TRIGGER_MODE_TICK := "tick"
const TRIGGER_MODE_EVENT := "event"
const TRIGGER_MODE_BOTH := "both"

const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/game/cfg_checkpoint_rule.tres"),
	preload("res://resources/qb/game/cfg_victory_rule.tres"),
]

@export var state_store: I_StateStore = null
@export var rules: Array[Resource] = []

var _rule_evaluator: Variant = U_RULE_EVALUATOR.new()

func on_configured() -> void:
	_refresh_rule_evaluator()
	_subscribe_rule_events()

func _exit_tree() -> void:
	_rule_evaluator.unsubscribe()

func process_tick(delta: float) -> void:
	_rule_evaluator.tick_cooldowns(delta)
	if not _rule_evaluator.has_tick_rules():
		return

	var context: Dictionary = _build_tick_context()
	_evaluate_context(context, TRIGGER_MODE_TICK, StringName())
	_rule_evaluator.cleanup_stale_contexts([_context_key_for_context(context)])

func get_rule_validation_report() -> Dictionary:
	return _rule_evaluator.get_rule_validation_report()

func _refresh_rule_evaluator() -> void:
	_rule_evaluator.refresh(DEFAULT_RULE_DEFINITIONS, rules)

func _subscribe_rule_events() -> void:
	_rule_evaluator.subscribe(
		func(rule_variant: Variant) -> Array[StringName]:
			return _extract_event_names_from_rule(rule_variant),
		func(event_name: StringName, event_payload: Dictionary) -> void:
			_on_event_received(event_name, event_payload)
	)

func _on_event_received(event_name: StringName, event_payload: Dictionary) -> void:
	_rule_evaluator.tick_cooldowns(0.0)
	var context: Dictionary = _build_event_context(event_name, event_payload)
	_evaluate_context(context, TRIGGER_MODE_EVENT, event_name)
	_rule_evaluator.cleanup_stale_contexts([_context_key_for_context(context)])

func _evaluate_context(context: Dictionary, trigger_mode: String, _event_name: StringName) -> void:
	_rule_evaluator.evaluate(
		context,
		trigger_mode,
		_event_name,
		_context_key_for_context(context),
		Callable(),
		func(winners: Array[Dictionary], evaluation_context: Dictionary) -> void:
			_execute_effects(winners, evaluation_context)
	)

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

func _extract_event_names_from_rule(rule_variant: Variant) -> Array[StringName]:
	var event_names: Array[StringName] = []
	if rule_variant == null or not (rule_variant is Object):
		return event_names

	var conditions_variant: Variant = (rule_variant as Object).get("conditions")
	if not (conditions_variant is Array):
		return event_names

	for condition_variant in conditions_variant as Array:
		_collect_event_names_from_condition(condition_variant, event_names)

	return event_names

func _collect_event_names_from_condition(condition_variant: Variant, event_names: Array[StringName]) -> void:
	if condition_variant == null or not (condition_variant is Object):
		return
	var condition_object: Object = condition_variant as Object

	if _is_script_instance_of(condition_object, CONDITION_EVENT_NAME_SCRIPT):
		var condition_event_name: StringName = _read_string_name_property(
			condition_object,
			"expected_event_name"
		)
		if condition_event_name == StringName():
			return
		if event_names.has(condition_event_name):
			return
		event_names.append(condition_event_name)
		return

	if not _is_script_instance_of(condition_object, CONDITION_COMPOSITE_SCRIPT):
		return

	var children_variant: Variant = condition_object.get("children")
	if not (children_variant is Array):
		return

	for child_condition_variant in children_variant as Array:
		_collect_event_names_from_condition(child_condition_variant, event_names)

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
