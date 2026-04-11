@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_GameEventSystem

const RSRuleContext := preload("res://scripts/resources/ecs/rs_rule_context.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_RULE_EVALUATOR := preload("res://scripts/utils/ecs/u_rule_evaluator.gd")
const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")
const EFFECT_PUBLISH_EVENT_SCRIPT := preload("res://scripts/resources/qb/effects/rs_effect_publish_event.gd")

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
			return U_RuleUtils.extract_event_names_from_rule(rule_variant),
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

	var event_name: StringName = U_RuleUtils.read_string_name_property(effect_variant, "event_name")
	if event_name == StringName():
		return

	var payload: Dictionary = {}
	var event_payload_variant: Variant = context.get(RSRuleContext.KEY_EVENT_PAYLOAD, {})
	if event_payload_variant is Dictionary:
		payload = (event_payload_variant as Dictionary).duplicate(true)

	var configured_payload_variant: Variant = effect_variant.get("payload")
	if configured_payload_variant is Dictionary:
		payload.merge((configured_payload_variant as Dictionary).duplicate(true), true)

	var inject_entity_id: bool = U_RuleUtils.read_bool_property(effect_variant, "inject_entity_id", true)
	var entity_id: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_ENTITY_ID)
	if inject_entity_id and entity_id != null and not payload.has("entity_id"):
		payload["entity_id"] = entity_id

	U_ECS_EVENT_BUS.publish(event_name, payload)

func _build_tick_context() -> Dictionary:
	var store: I_StateStore = _resolve_store()
	var rule_context := RSRuleContext.new()
	if store != null:
		rule_context.state_store = store
		var redux_state: Dictionary = store.get_state()
		if not redux_state.is_empty():
			rule_context.redux_state = redux_state.duplicate(true)

	return rule_context.to_dictionary()

func _build_event_context(event_name: StringName, event_payload: Dictionary) -> Dictionary:
	var context: Dictionary = _build_tick_context()
	context[RSRuleContext.KEY_EVENT_NAME] = event_name
	context[RSRuleContext.KEY_EVENT_PAYLOAD] = event_payload.duplicate(true)

	var entity_id: Variant = _extract_entity_id(event_payload)
	if entity_id != null:
		context[RSRuleContext.KEY_ENTITY_ID] = entity_id

	_attach_entity_context(context)
	return context

func _attach_entity_context(context: Dictionary) -> void:
	var entity_id_variant: Variant = context.get(RSRuleContext.KEY_ENTITY_ID, null)
	if entity_id_variant == null:
		return

	var entity_id: StringName = U_RuleUtils.variant_to_string_name(entity_id_variant)
	if entity_id == StringName():
		return

	var manager: I_ECSManager = get_manager()
	if manager == null:
		return

	var entity: Node = manager.get_entity_by_id(entity_id)
	if entity == null:
		return

	context[RSRuleContext.KEY_ENTITY] = entity
	if entity.has_method("get_tags"):
		var tags_variant: Variant = entity.call("get_tags")
		if tags_variant is Array:
			context[RSRuleContext.KEY_ENTITY_TAGS] = tags_variant

	var components: Dictionary = manager.get_components_for_entity(entity)
	if components.is_empty():
		return

	context[RSRuleContext.KEY_COMPONENTS] = components.duplicate(true)
	context[RSRuleContext.KEY_COMPONENT_DATA] = context.get(RSRuleContext.KEY_COMPONENTS)

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
	var entity_id_variant: Variant = context.get(RSRuleContext.KEY_ENTITY_ID, null)
	var entity_id: StringName = U_RuleUtils.variant_to_string_name(entity_id_variant)
	if entity_id != StringName():
		return entity_id
	return StringName()

func _resolve_store() -> I_StateStore:
	return U_DependencyResolution.resolve_state_store(null, state_store, self)

func _is_publish_event_effect(effect_variant: Variant) -> bool:
	if effect_variant == null or not (effect_variant is Object):
		return false
	return U_RuleUtils.is_script_instance_of(effect_variant as Object, EFFECT_PUBLISH_EVENT_SCRIPT)