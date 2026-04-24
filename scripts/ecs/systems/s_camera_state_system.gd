@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_CameraStateSystem

const U_CAMERA_STATE_RULE_APPLIER := preload("res://scripts/ecs/systems/helpers/u_camera_state_rule_applier.gd")
const RSRuleContext := preload("res://scripts/core/resources/ecs/rs_rule_context.gd")
const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const U_RULE_EVALUATOR := preload("res://scripts/utils/ecs/u_rule_evaluator.gd")
const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const MOVEMENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const CAMERA_MANAGER_SERVICE := StringName("camera_manager")
const PRIMARY_PLAYER_ENTITY_ID := StringName("player")


const TRIGGER_MODE_TICK := "tick"
const TRIGGER_MODE_EVENT := "event"
const TRIGGER_MODE_BOTH := "both"

const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/camera/cfg_camera_shake_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_zone_fov_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_speed_fov_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_landing_impact_rule.tres"),
]

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var camera_state_config: Resource = null
@export var rules: Array[RS_Rule] = []:
	get:
		return _rules
	set(value):
		_rules = _coerce_rules(value)

var _rules: Array[RS_Rule] = []
var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_StateStore = null
var _rule_evaluator: Variant = U_RULE_EVALUATOR.new()
var _rule_applier = U_CAMERA_STATE_RULE_APPLIER.new()


func _coerce_rules(value: Variant) -> Array[RS_Rule]:
	var coerced: Array[RS_Rule] = []
	if not (value is Array):
		return coerced
	for rule_variant in value as Array:
		if rule_variant is RS_Rule:
			coerced.append(rule_variant as RS_Rule)
	return coerced

func on_configured() -> void:
	_refresh_rule_evaluator()
	_subscribe_rule_events()
	_camera_manager = _resolve_camera_manager()
	_rule_applier.configure(camera_state_config)

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.CAMERA

func _exit_tree() -> void:
	_rule_evaluator.unsubscribe()

func process_tick(delta: float) -> void:
	_rule_evaluator.tick_cooldowns(delta)

	var contexts: Array = _build_camera_contexts(StringName(), {})
	if contexts.is_empty():
		var manager_when_empty: I_CAMERA_MANAGER = _resolve_camera_manager()
		if manager_when_empty != null:
			manager_when_empty.clear_shake_source(U_CAMERA_STATE_RULE_APPLIER.CAMERA_SHAKE_SOURCE)
		return

	var active_context_keys: Array = []
	if _rule_evaluator.has_tick_rules():
		for context_variant in contexts:
			if not (context_variant is Dictionary):
				continue
			var context: Dictionary = context_variant as Dictionary
			active_context_keys.append(_context_key_for_context(context))
			_evaluate_context(context, TRIGGER_MODE_TICK, StringName())
	else:
		for context_variant in contexts:
			if not (context_variant is Dictionary):
				continue
			var context: Dictionary = context_variant as Dictionary
			active_context_keys.append(_context_key_for_context(context))

	_rule_evaluator.cleanup_stale_contexts(active_context_keys)
	var apply_manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	_rule_applier.apply_camera_state(contexts, delta, apply_manager)

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
	var contexts: Array = _build_camera_contexts(event_name, event_payload)
	if contexts.is_empty():
		return

	var active_context_keys: Array = []
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant as Dictionary
		active_context_keys.append(_context_key_for_context(context))
		_evaluate_context(context, TRIGGER_MODE_EVENT, event_name)

	_rule_evaluator.cleanup_stale_contexts(active_context_keys)
	var event_manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	_rule_applier.apply_camera_state(contexts, 0.0, event_manager)

func _evaluate_context(context: Dictionary, trigger_mode: String, event_name: StringName) -> void:
	_rule_evaluator.evaluate(
		context,
		trigger_mode,
		event_name,
		_context_key_for_context(context),
		func(rule_variant: Variant, callback_event_name: StringName) -> bool:
			if trigger_mode != TRIGGER_MODE_EVENT:
				return true
			if callback_event_name == StringName():
				return true
			return _rule_handles_event(rule_variant, callback_event_name),
		func(winners: Array[Dictionary], evaluation_context: Dictionary) -> void:
			_execute_effects(winners, evaluation_context)
	)

func _rule_handles_event(rule_variant: Variant, event_name: StringName) -> bool:
	if event_name == StringName():
		return true
	var event_names: Array[StringName] = U_RuleUtils.extract_event_names_from_rule(rule_variant)
	if event_names.is_empty():
		return false
	return event_names.has(event_name)

func _execute_effects(winners: Array[Dictionary], context: Dictionary) -> void:
	for winner in winners:
		var rule_variant: Variant = winner.get("rule", null)
		if rule_variant == null or not (rule_variant is Object):
			continue
		var had_rule_score: bool = context.has(RSRuleContext.KEY_RULE_SCORE)
		var previous_rule_score: Variant = context.get(RSRuleContext.KEY_RULE_SCORE, 1.0)
		context[RSRuleContext.KEY_RULE_SCORE] = _resolve_winner_score(winner)

		var effects_variant: Variant = rule_variant.get("effects")
		if not (effects_variant is Array):
			if had_rule_score:
				context[RSRuleContext.KEY_RULE_SCORE] = previous_rule_score
			else:
				context.erase(RSRuleContext.KEY_RULE_SCORE)
			continue

		for effect_variant in (effects_variant as Array):
			if effect_variant == null or not (effect_variant is Object):
				continue
			if not effect_variant is I_Effect:
				continue
			effect_variant.call("execute", context)

		if had_rule_score:
			context[RSRuleContext.KEY_RULE_SCORE] = previous_rule_score
		else:
			context.erase(RSRuleContext.KEY_RULE_SCORE)

func _context_key_for_context(context: Dictionary) -> StringName:
	var camera_entity_id: StringName = U_RuleUtils.variant_to_string_name(U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CAMERA_ENTITY_ID))
	if camera_entity_id != StringName():
		return camera_entity_id

	var entity_id: StringName = U_RuleUtils.variant_to_string_name(U_RuleUtils.get_context_value(context, RSRuleContext.KEY_ENTITY_ID))
	if entity_id != StringName():
		return entity_id

	return StringName()

func _build_camera_contexts(event_name: StringName, event_payload: Dictionary) -> Array:
	var contexts: Array = []
	var store: I_StateStore = _resolve_state_store()
	var redux_state: Dictionary = get_frame_state_snapshot()
	var movement_snapshot: Dictionary = _resolve_primary_movement_snapshot()

	var entities: Array = query_entities([CAMERA_STATE_TYPE])
	for entity_query_variant in entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue

		var camera_state: Variant = entity_query.call("get_component", CAMERA_STATE_TYPE)
		if camera_state == null:
			continue

		var rule_context := RSRuleContext.new()
		if store != null:
			rule_context.state_store = store
		if not redux_state.is_empty():
			rule_context.redux_state = redux_state
		rule_context.vcam_active_mode = U_VCAM_SELECTORS.get_active_mode(redux_state)
		rule_context.vcam_is_blending = U_VCAM_SELECTORS.is_blending(redux_state)
		rule_context.vcam_active_vcam_id = U_VCAM_SELECTORS.get_active_vcam_id(redux_state)
		if event_name != StringName():
			rule_context.event_name = event_name
		if not event_payload.is_empty():
			rule_context.event_payload = event_payload

		_attach_camera_context(rule_context, entity_query, camera_state, movement_snapshot)
		contexts.append(rule_context.to_dictionary())

	return contexts

func _attach_camera_context(
	rule_context,
	entity_query: Object,
	camera_state: Variant,
	movement_snapshot: Dictionary
) -> void:
	rule_context.camera_state_component = camera_state

	var components: Dictionary = {}
	components[CAMERA_STATE_TYPE] = camera_state
	components[String(CAMERA_STATE_TYPE)] = camera_state
	if not movement_snapshot.is_empty():
		var movement_data: Dictionary = movement_snapshot.duplicate(true)
		components[MOVEMENT_TYPE] = movement_data
		components[String(MOVEMENT_TYPE)] = movement_data
		rule_context.movement_component = movement_data
	rule_context.components = components

	if entity_query.has_method("get_entity_id"):
		var camera_entity_id: Variant = entity_query.call("get_entity_id")
		var camera_entity_id_sn: StringName = U_RuleUtils.variant_to_string_name(camera_entity_id) if camera_entity_id != null else &""
		rule_context.camera_entity_id = camera_entity_id_sn
		rule_context.entity_id = camera_entity_id_sn
	if entity_query.has_method("get_tags"):
		var camera_tags: Variant = entity_query.call("get_tags")
		if camera_tags is Array:
			rule_context.camera_entity_tags = camera_tags
			rule_context.entity_tags = camera_tags

	if "entity" in entity_query:
		var camera_entity: Variant = entity_query.get("entity")
		if camera_entity != null:
			rule_context.camera_entity = camera_entity
			rule_context.entity = camera_entity

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	_camera_manager = U_DependencyResolution.resolve(CAMERA_MANAGER_SERVICE, _camera_manager, camera_manager) as I_CAMERA_MANAGER
	return _camera_manager

func _resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self)
	return _state_store

func _extract_event_payload(event_data: Dictionary) -> Dictionary:
	var payload_variant: Variant = event_data.get("payload", null)
	if payload_variant is Dictionary:
		return (payload_variant as Dictionary).duplicate(true)
	if event_data is Dictionary:
		return event_data.duplicate(true)
	return {}

func _resolve_winner_score(winner: Dictionary) -> float:
	var score_variant: Variant = winner.get("score", 1.0)
	if score_variant is float or score_variant is int:
		return clampf(float(score_variant), 0.0, 1.0)
	return 1.0

func _resolve_primary_movement_snapshot() -> Dictionary:
	var movement_component: Variant = _resolve_primary_movement_component()
	if movement_component == null:
		return {}
	return {
		"speed_magnitude": _extract_movement_speed_magnitude(movement_component),
	}

func _resolve_primary_movement_component() -> Variant:
	var movement_entities: Array = query_entities([MOVEMENT_TYPE])
	var fallback_component: Variant = null
	for entity_query_variant in movement_entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue
		var movement_component: Variant = entity_query.call("get_component", MOVEMENT_TYPE)
		if movement_component == null:
			continue
		if fallback_component == null:
			fallback_component = movement_component
		if _is_primary_player_query(entity_query):
			return movement_component
	return fallback_component

func _is_primary_player_query(entity_query: Object) -> bool:
	if entity_query.has_method("get_entity_id"):
		var entity_id: StringName = U_RuleUtils.variant_to_string_name(entity_query.call("get_entity_id"))
		if entity_id == PRIMARY_PLAYER_ENTITY_ID:
			return true
	if entity_query.has_method("get_tags"):
		var tags_variant: Variant = entity_query.call("get_tags")
		if tags_variant is Array:
			var tags: Array = tags_variant as Array
			return tags.has(PRIMARY_PLAYER_ENTITY_ID) or tags.has(String(PRIMARY_PLAYER_ENTITY_ID))
	return false

func _extract_movement_speed_magnitude(movement_component: Variant) -> float:
	if movement_component == null or not (movement_component is Object):
		return 0.0
	var object_value: Object = movement_component as Object
	if object_value.has_method("get_horizontal_dynamics_velocity"):
		var velocity_variant: Variant = object_value.call("get_horizontal_dynamics_velocity")
		if velocity_variant is Vector2:
			return (velocity_variant as Vector2).length()
		if velocity_variant is Vector3:
			return (velocity_variant as Vector3).length()
	return 0.0
