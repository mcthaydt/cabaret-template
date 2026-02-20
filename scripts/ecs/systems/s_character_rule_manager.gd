@icon("res://assets/editor_icons/icn_system.svg")
extends BaseQBRuleManager
class_name S_CharacterRuleManager

const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/ecs/components/c_health_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")

const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const FLOATING_TYPE := C_FLOATING_COMPONENT.COMPONENT_TYPE
const HEALTH_TYPE := C_HEALTH_COMPONENT.COMPONENT_TYPE
const INPUT_TYPE := C_INPUT_COMPONENT.COMPONENT_TYPE
const MOVEMENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const SPAWN_STATE_TYPE := C_SPAWN_STATE_COMPONENT.COMPONENT_TYPE

func get_default_rule_definitions() -> Array:
	return []

func process_tick(delta: float) -> void:
	_tick_cooldowns(delta)
	_begin_tick_context_tracking()
	var contexts: Array = _get_tick_contexts(delta)
	_evaluate_contexts(contexts, QB_RULE.TriggerMode.TICK)
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant
		var character_state: Variant = context.get("character_state_component", null)
		_write_brain_data(character_state, context)
	_cleanup_stale_context_state()

func _get_tick_contexts(delta: float) -> Array:
	var contexts: Array = []
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = {}
	if store != null:
		redux_state = store.get_state()

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
		var entity_query: Variant = entity_query_variant
		if entity_query == null:
			continue
		if not (entity_query is Object):
			continue
		if not entity_query.has_method("get_component"):
			continue

		var character_state: Variant = entity_query.call("get_component", CHARACTER_STATE_TYPE)
		if character_state == null:
			continue

		var context: Dictionary = _build_quality_context(character_state, delta, entity_query, redux_state, store)
		contexts.append(context)

	return contexts

func _build_quality_context(
	character_state: Variant,
	_delta: float,
	entity_query: Variant = null,
	redux_state: Dictionary = {},
	store: I_StateStore = null
) -> Dictionary:
	var context: Dictionary = {
		"is_gameplay_active": true,
		"is_grounded": false,
		"is_moving": false,
		"is_spawn_frozen": false,
		"is_dead": false,
		"is_invincible": false,
		"health_percent": 1.0,
		"vertical_state": C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_GROUNDED,
		"has_input": false,
		"character_state_component": character_state,
		"redux_state": redux_state.duplicate(true),
	}
	context["state"] = context["redux_state"]
	if store != null:
		context["state_store"] = store

	var components: Dictionary = {}
	components[CHARACTER_STATE_TYPE] = character_state
	components[String(CHARACTER_STATE_TYPE)] = character_state

	if entity_query != null and entity_query is Object:
		var query_object: Object = entity_query as Object
		if query_object.has_method("get_entity_id"):
			context["entity_id"] = query_object.call("get_entity_id")
		if query_object.has_method("get_tags"):
			context["entity_tags"] = query_object.call("get_tags")
		var entity_variant: Variant = query_object.get("entity")
		if entity_variant != null:
			context["entity"] = entity_variant

		_add_component_from_query(query_object, components, FLOATING_TYPE)
		_add_component_from_query(query_object, components, HEALTH_TYPE)
		_add_component_from_query(query_object, components, INPUT_TYPE)
		_add_component_from_query(query_object, components, MOVEMENT_TYPE)
		_add_component_from_query(query_object, components, SPAWN_STATE_TYPE)

	context["components"] = components
	context["component_data"] = components

	var health_component: Variant = _get_component(components, HEALTH_TYPE)
	var input_component: Variant = _get_component(components, INPUT_TYPE)
	var movement_component: Variant = _get_component(components, MOVEMENT_TYPE)
	var spawn_component: Variant = _get_component(components, SPAWN_STATE_TYPE)
	var floating_component: Variant = _get_component(components, FLOATING_TYPE)
	var body: CharacterBody3D = _resolve_character_body(
		movement_component,
		floating_component,
		spawn_component,
		health_component
	)

	if input_component != null:
		var move_vector_variant: Variant = input_component.get("move_vector")
		if move_vector_variant is Vector2:
			var move_vector: Vector2 = move_vector_variant
			context["has_input"] = move_vector.length() > 0.0

	if spawn_component != null:
		context["is_spawn_frozen"] = bool(spawn_component.get("is_physics_frozen"))

	if health_component != null:
		context["is_invincible"] = bool(health_component.get("is_invincible"))
		if health_component.has_method("is_dead"):
			context["is_dead"] = bool(health_component.call("is_dead"))
		else:
			context["is_dead"] = bool(health_component.get("is_dead"))

		var max_health: float = 0.0
		var current_health: float = 0.0
		if health_component.has_method("get_max_health"):
			max_health = maxf(float(health_component.call("get_max_health")), 0.0)
		elif _object_has_property(health_component, "max_health"):
			max_health = maxf(float(health_component.get("max_health")), 0.0)

		if health_component.has_method("get_current_health"):
			current_health = maxf(float(health_component.call("get_current_health")), 0.0)
		elif _object_has_property(health_component, "current_health"):
			current_health = maxf(float(health_component.get("current_health")), 0.0)

		if max_health > 0.0:
			context["health_percent"] = clampf(current_health / max_health, 0.0, 1.0)
		else:
			context["health_percent"] = 0.0

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

	context["is_grounded"] = is_grounded
	context["is_moving"] = is_moving
	context["vertical_state"] = vertical_state

	return context

func _write_brain_data(character_state: Variant, context: Dictionary) -> void:
	if character_state == null:
		return
	if not (character_state is Object):
		return

	character_state.set("is_gameplay_active", bool(context.get("is_gameplay_active", true)))
	character_state.set("is_grounded", bool(context.get("is_grounded", false)))
	character_state.set("is_moving", bool(context.get("is_moving", false)))
	character_state.set("is_spawn_frozen", bool(context.get("is_spawn_frozen", false)))
	character_state.set("is_dead", bool(context.get("is_dead", false)))
	character_state.set("is_invincible", bool(context.get("is_invincible", false)))
	character_state.set("vertical_state", _resolve_vertical_state(context))
	character_state.set("has_input", bool(context.get("has_input", false)))

	var health_percent: float = clampf(float(context.get("health_percent", 1.0)), 0.0, 1.0)
	if character_state.has_method("set_health_percent"):
		character_state.call("set_health_percent", health_percent)
	else:
		character_state.set("health_percent", health_percent)

func _resolve_store() -> I_StateStore:
	if state_store != null:
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _add_component_from_query(query_object: Object, components: Dictionary, component_type: StringName) -> void:
	var component: Variant = query_object.call("get_component", component_type)
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
	body = _read_character_body(health_component)
	return body

func _read_character_body(component: Variant) -> CharacterBody3D:
	if component == null:
		return null
	if not (component is Object):
		return null
	if not component.has_method("get_character_body"):
		return null
	return component.call("get_character_body") as CharacterBody3D

func _resolve_vertical_state(context: Dictionary) -> int:
	var value: int = int(context.get("vertical_state", C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_GROUNDED))
	match value:
		C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_FALLING:
			return C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_FALLING
		C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING:
			return C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING
		_:
			return C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_GROUNDED

func _object_has_property(object_value: Variant, property_name: String) -> bool:
	if object_value == null or not (object_value is Object):
		return false
	var object_data: Object = object_value as Object
	var properties: Array = object_data.get_property_list()
	for property_info_variant in properties:
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant as Dictionary
		var name_variant: Variant = property_info.get("name", "")
		if String(name_variant) == property_name:
			return true
	return false
