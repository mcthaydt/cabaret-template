@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_CharacterStateSystem

const RSRuleContext := preload("res://scripts/resources/ecs/rs_rule_context.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/ecs/components/c_health_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")
const U_RULE_EVALUATOR := preload("res://scripts/utils/ecs/u_rule_evaluator.gd")
const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")

const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const FLOATING_TYPE := C_FLOATING_COMPONENT.COMPONENT_TYPE
const HEALTH_TYPE := C_HEALTH_COMPONENT.COMPONENT_TYPE
const INPUT_TYPE := C_INPUT_COMPONENT.COMPONENT_TYPE
const MOVEMENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const SPAWN_STATE_TYPE := C_SPAWN_STATE_COMPONENT.COMPONENT_TYPE

const TRIGGER_MODE_TICK := "tick"
const TRIGGER_MODE_EVENT := "event"
const TRIGGER_MODE_BOTH := "both"

const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/character/cfg_pause_gate_paused.tres"),
	preload("res://resources/qb/character/cfg_pause_gate_shell.tres"),
	preload("res://resources/qb/character/cfg_pause_gate_transitioning.tres"),
	preload("res://resources/qb/character/cfg_spawn_freeze_rule.tres"),
	preload("res://resources/qb/character/cfg_death_sync_rule.tres"),
]

@export var state_store: I_StateStore = null
@export var rules: Array[RS_Rule] = []:
	get:
		return _rules
	set(value):
		_rules = _coerce_rules(value)

var _rules: Array[RS_Rule] = []
var _rule_evaluator: Variant = U_RULE_EVALUATOR.new()
var _state_store: I_StateStore = null


func _coerce_rules(value: Variant) -> Array[RS_Rule]:
	var coerced: Array[RS_Rule] = []
	if not (value is Array):
		return coerced
	for rule_variant in value as Array:
		if rule_variant is RS_Rule:
			coerced.append(rule_variant as RS_Rule)
	return coerced

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.POST_PHYSICS

func on_configured() -> void:
	_refresh_rule_evaluator()
	_subscribe_rule_events()

func _exit_tree() -> void:
	_rule_evaluator.unsubscribe()

func process_tick(delta: float) -> void:
	_rule_evaluator.tick_cooldowns(delta)

	var contexts: Array = _build_entity_contexts()
	if contexts.is_empty():
		return

	var active_context_keys: Array = []
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant
		active_context_keys.append(_context_key_for_context(context))
		_evaluate_context(context, TRIGGER_MODE_TICK, StringName())
		var character_state: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CHARACTER_STATE_COMPONENT)
		_write_brain_data(character_state, context)

	_rule_evaluator.cleanup_stale_contexts(active_context_keys)

func get_rule_validation_report() -> Dictionary:
	return _rule_evaluator.get_rule_validation_report()

func _refresh_rule_evaluator() -> void:
	_rule_evaluator.refresh(DEFAULT_RULE_DEFINITIONS, rules)

func _subscribe_rule_events() -> void:
	_rule_evaluator.subscribe(
		func(rule_variant: Variant) -> Array[StringName]:
			return U_RuleUtils.extract_event_names_from_rule(rule_variant),
		func(event_name: StringName, event_payload: Dictionary) -> void:
				_on_rule_event(event_name, event_payload)
	)

func _on_rule_event(event_name: StringName, event_payload: Dictionary) -> void:
	_rule_evaluator.tick_cooldowns(0.0)

	var contexts: Array = _build_entity_contexts()
	if contexts.is_empty():
		return

	var active_context_keys: Array = []
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant
		# Add event fields to the context dictionary
		context[RSRuleContext.KEY_EVENT_NAME] = event_name
		context[RSRuleContext.KEY_EVENT_PAYLOAD] = event_payload.duplicate(true)

		active_context_keys.append(_context_key_for_context(context))
		_evaluate_context(context, TRIGGER_MODE_EVENT, event_name)
		var character_state: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CHARACTER_STATE_COMPONENT)
		_write_brain_data(character_state, context)

	_rule_evaluator.cleanup_stale_contexts(active_context_keys)

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
			if not effect_variant is I_Effect:
				continue
			effect_variant.call("execute", context)

func _context_key_for_context(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = context.get(RSRuleContext.KEY_ENTITY_ID, StringName())
	return U_RuleUtils.variant_to_string_name(entity_id_variant)

func _build_entity_contexts() -> Array:
	var contexts: Array = []
	var redux_state: Dictionary = get_frame_state_snapshot()
	var store: I_StateStore = _resolve_state_store()

	var entities: Array = query_entities(
		[CHARACTER_STATE_TYPE],
		[
			FLOATING_TYPE,
			HEALTH_TYPE,
			INPUT_TYPE,
			MOVEMENT_TYPE,
			SPAWN_STATE_TYPE,
		]
	)

	for entity_query_variant in entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue

		var character_state: Variant = entity_query.call("get_component", CHARACTER_STATE_TYPE)
		if character_state == null:
			continue

		var rule_context := RSRuleContext.new()
		if store != null:
			rule_context.state_store = store
		if not redux_state.is_empty():
			rule_context.redux_state = redux_state
		_populate_entity_context(rule_context, entity_query, character_state)

		var components: Dictionary = _populate_component_map(rule_context, entity_query)
		var health_component: Variant = _get_component(components, HEALTH_TYPE)
		var input_component: Variant = _get_component(components, INPUT_TYPE)
		var movement_component: Variant = _get_component(components, MOVEMENT_TYPE)
		var spawn_component: Variant = _get_component(components, SPAWN_STATE_TYPE)
		var floating_component: Variant = _get_component(components, FLOATING_TYPE)
		var body: CharacterBody3D = _resolve_character_body(movement_component, floating_component, spawn_component, health_component)

		_populate_health_state(rule_context, health_component)
		_populate_movement_state(rule_context, body, floating_component)
		_populate_input_state(rule_context, input_component)

		contexts.append(rule_context.to_dictionary())

	return contexts

func _populate_entity_context(rule_context, entity_query: Object, character_state: Variant) -> void:
	rule_context.character_state_component = character_state
	if entity_query.has_method("get_entity_id"):
		var entity_id: Variant = entity_query.call("get_entity_id")
		rule_context.entity_id = U_RuleUtils.variant_to_string_name(entity_id) if entity_id != null else &""
	if entity_query.has_method("get_tags"):
		var tags_variant: Variant = entity_query.call("get_tags")
		if tags_variant is Array:
			rule_context.entity_tags = tags_variant

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant != null:
		rule_context.entity = entity_variant

func _populate_component_map(rule_context, entity_query: Object) -> Dictionary:
	var components: Dictionary = {}
	var character_state: Variant = rule_context.character_state_component
	components[CHARACTER_STATE_TYPE] = character_state
	components[String(CHARACTER_STATE_TYPE)] = character_state

	_add_component_from_query(entity_query, components, FLOATING_TYPE)
	_add_component_from_query(entity_query, components, HEALTH_TYPE)
	_add_component_from_query(entity_query, components, INPUT_TYPE)
	_add_component_from_query(entity_query, components, MOVEMENT_TYPE)
	_add_component_from_query(entity_query, components, SPAWN_STATE_TYPE)

	rule_context.components = components
	return components

func _populate_health_state(rule_context, health_component: Variant) -> void:
	if health_component == null:
		return

	rule_context.is_invincible = bool(health_component.get("is_invincible"))

	var max_health: float = 0.0
	var current_health: float = 0.0
	if health_component.has_method("get_max_health"):
		max_health = maxf(float(health_component.call("get_max_health")), 0.0)
	elif U_RuleUtils.object_has_property(health_component, "max_health"):
		max_health = maxf(float(health_component.get("max_health")), 0.0)

	if health_component.has_method("get_current_health"):
		current_health = maxf(float(health_component.call("get_current_health")), 0.0)
	elif U_RuleUtils.object_has_property(health_component, "current_health"):
		current_health = maxf(float(health_component.get("current_health")), 0.0)

	if max_health > 0.0:
		rule_context.health_percent = clampf(current_health / max_health, 0.0, 1.0)
	else:
		rule_context.health_percent = 0.0

func _populate_movement_state(rule_context, body: CharacterBody3D, floating_component: Variant) -> void:
	var floating_grounded: bool = false
	if floating_component != null:
		floating_grounded = bool(floating_component.get("grounded_stable")) or bool(floating_component.get("is_supported"))

	var is_grounded: bool = floating_grounded
	var is_moving: bool = false
	var vertical_state: int = C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_GROUNDED
	if body != null:
		is_grounded = is_grounded or body.is_on_floor()
		var horizontal_speed: float = Vector2(body.velocity.x, body.velocity.z).length()
		is_moving = horizontal_speed > 0.1
		if not is_grounded:
			if body.velocity.y > 0.01:
				vertical_state = C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING
			elif body.velocity.y < -0.01:
				vertical_state = C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_FALLING

	rule_context.is_grounded = is_grounded
	rule_context.is_moving = is_moving
	rule_context.vertical_state = vertical_state

func _populate_input_state(rule_context, input_component: Variant) -> void:
	if input_component == null:
		return

	var move_vector_variant: Variant = input_component.get("move_vector")
	if move_vector_variant is Vector2:
		var move_vector: Vector2 = move_vector_variant
		rule_context.has_input = move_vector.length() > 0.0

func _write_brain_data(character_state: Variant, context: Dictionary) -> void:
	if character_state == null or not (character_state is Object):
		return

	# Context dictionaries from RSRuleContext.to_dictionary() always include character state fields
	character_state.set("is_gameplay_active", context.get(RSRuleContext.KEY_IS_GAMEPLAY_ACTIVE, true))
	character_state.set("is_grounded", context.get(RSRuleContext.KEY_IS_GROUNDED, false))
	character_state.set("is_moving", context.get(RSRuleContext.KEY_IS_MOVING, false))
	character_state.set("is_spawn_frozen", context.get(RSRuleContext.KEY_IS_SPAWN_FROZEN, false))
	character_state.set("is_dead", context.get(RSRuleContext.KEY_IS_DEAD, false))
	character_state.set("is_invincible", context.get(RSRuleContext.KEY_IS_INVINCIBLE, false))
	character_state.set("vertical_state", _resolve_vertical_state(context))
	character_state.set("has_input", context.get(RSRuleContext.KEY_HAS_INPUT, false))

	var health_percent: float = clampf(float(context.get(RSRuleContext.KEY_HEALTH_PERCENT, 1.0)), 0.0, 1.0)
	if character_state.has_method("set_health_percent"):
		character_state.call("set_health_percent", health_percent)
	else:
		character_state.set("health_percent", health_percent)

func _add_component_from_query(entity_query: Object, components: Dictionary, component_type: StringName) -> void:
	var component: Variant = entity_query.call("get_component", component_type)
	if component == null:
		return
	components[component_type] = component
	components[String(component_type)] = component

func _get_component(components: Dictionary, component_type: StringName) -> Variant:
	if components.has(component_type):
		return components.get(component_type)

	var key: String = String(component_type)
	if components.has(key):
		return components.get(key)

	return null

func _resolve_character_body(
	movement_component: Variant,
	floating_component: Variant,
	spawn_component: Variant,
	health_component: Variant
) -> CharacterBody3D:
	var body: CharacterBody3D = _read_character_body(movement_component)
	if body != null:
		return body

	body = _read_character_body(floating_component)
	if body != null:
		return body

	body = _read_character_body(spawn_component)
	if body != null:
		return body

	return _read_character_body(health_component)

func _read_character_body(component: Variant) -> CharacterBody3D:
	if component == null or not (component is Object):
		return null
	if not component.has_method("get_character_body"):
		return null
	return component.call("get_character_body") as CharacterBody3D

func _resolve_vertical_state(context: Dictionary) -> int:
	var value: int = int(context.get(RSRuleContext.KEY_VERTICAL_STATE, C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_GROUNDED))
	match value:
		C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_FALLING:
			return C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_FALLING
		C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING:
			return C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING
		_:
			return C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_GROUNDED

func _resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self)
	return _state_store