@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_CameraStateSystem

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const U_RULE_EVALUATOR := preload("res://scripts/utils/ecs/u_rule_evaluator.gd")
const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const MOVEMENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const CAMERA_MANAGER_SERVICE := StringName("camera_manager")
const CAMERA_SHAKE_SOURCE := StringName("qb_camera_rule")
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")
const PRIMARY_PLAYER_ENTITY_ID := StringName("player")

const RULE_SCORE_CONTEXT_KEY := "rule_score"

const TRIGGER_MODE_TICK := "tick"
const TRIGGER_MODE_EVENT := "event"
const TRIGGER_MODE_BOTH := "both"

const SHAKE_TRAUMA_DECAY_RATE: float = 2.0
const SHAKE_MAX_OFFSET_PX: float = 10.0
const SHAKE_MAX_ROTATION_RAD: float = 0.03
const SHAKE_FREQ_OFFSET_X: float = 17.0
const SHAKE_FREQ_OFFSET_Y: float = 21.0
const SHAKE_FREQ_ROTATION: float = 13.0
const SHAKE_PHASE_OFFSET_X: float = 1.1
const SHAKE_PHASE_OFFSET_Y: float = 2.3
const SHAKE_PHASE_ROTATION: float = 0.7

const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/camera/cfg_camera_shake_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_zone_fov_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_speed_fov_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_landing_impact_rule.tres"),
]

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var rules: Array[Resource] = []

var _camera_manager: I_CAMERA_MANAGER = null
var _rule_evaluator: Variant = U_RULE_EVALUATOR.new()
var _shake_time: float = 0.0

func on_configured() -> void:
	_refresh_rule_evaluator()
	_subscribe_rule_events()
	_camera_manager = _resolve_camera_manager()

func _exit_tree() -> void:
	_rule_evaluator.unsubscribe()

func process_tick(delta: float) -> void:
	_rule_evaluator.tick_cooldowns(delta)

	var contexts: Array = _build_camera_contexts({})
	if contexts.is_empty():
		var manager_when_empty: I_CAMERA_MANAGER = _resolve_camera_manager()
		if manager_when_empty != null:
			manager_when_empty.clear_shake_source(CAMERA_SHAKE_SOURCE)
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
	_apply_camera_state(contexts, delta)

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
	var base_context: Dictionary = {
		"event_name": event_name,
		"event_payload": event_payload,
	}
	var contexts: Array = _build_camera_contexts(base_context)
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
	_apply_camera_state(contexts, 0.0)

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
		var had_rule_score: bool = context.has(RULE_SCORE_CONTEXT_KEY)
		var previous_rule_score: Variant = context.get(RULE_SCORE_CONTEXT_KEY, 1.0)
		context[RULE_SCORE_CONTEXT_KEY] = _resolve_winner_score(winner)

		var effects_variant: Variant = rule_variant.get("effects")
		if not (effects_variant is Array):
			if had_rule_score:
				context[RULE_SCORE_CONTEXT_KEY] = previous_rule_score
			else:
				context.erase(RULE_SCORE_CONTEXT_KEY)
			continue

		for effect_variant in (effects_variant as Array):
			if effect_variant == null or not (effect_variant is Object):
				continue
			if not effect_variant is I_Effect:
				continue
			effect_variant.call("execute", context)

		if had_rule_score:
			context[RULE_SCORE_CONTEXT_KEY] = previous_rule_score
		else:
			context.erase(RULE_SCORE_CONTEXT_KEY)

func _context_key_for_context(context: Dictionary) -> StringName:
	var camera_entity_id: StringName = U_RuleUtils.variant_to_string_name(U_RuleUtils.get_context_value(context, "camera_entity_id"))
	if camera_entity_id != StringName():
		return camera_entity_id

	var entity_id: StringName = U_RuleUtils.variant_to_string_name(U_RuleUtils.get_context_value(context, "entity_id"))
	if entity_id != StringName():
		return entity_id

	return StringName()

func _build_camera_contexts(base_context: Dictionary) -> Array:
	var contexts: Array = []
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = _get_frame_state_snapshot()
	if redux_state.is_empty():
		if store != null:
			redux_state = store.get_state()
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

		var context: Dictionary = base_context.duplicate(true)
		_attach_camera_context(context, entity_query, camera_state, redux_state, store, movement_snapshot)
		contexts.append(context)

	return contexts

func _attach_camera_context(
	context: Dictionary,
	entity_query: Object,
	camera_state: Variant,
	redux_state: Dictionary,
	store: I_StateStore,
	movement_snapshot: Dictionary
) -> void:
	context["camera_state_component"] = camera_state

	var components: Dictionary = {}
	components[CAMERA_STATE_TYPE] = camera_state
	components[String(CAMERA_STATE_TYPE)] = camera_state
	if not movement_snapshot.is_empty():
		var movement_data: Dictionary = movement_snapshot.duplicate(true)
		components[MOVEMENT_TYPE] = movement_data
		components[String(MOVEMENT_TYPE)] = movement_data
		context["movement_component"] = movement_data
	context["components"] = components
	context["component_data"] = components

	context["redux_state"] = redux_state
	context["state"] = context["redux_state"]
	context["vcam_active_mode"] = U_VCAM_SELECTORS.get_active_mode(redux_state)
	context["vcam_is_blending"] = U_VCAM_SELECTORS.is_blending(redux_state)
	context["vcam_active_vcam_id"] = U_VCAM_SELECTORS.get_active_vcam_id(redux_state)
	if store != null:
		context["state_store"] = store

	if entity_query.has_method("get_entity_id"):
		var camera_entity_id: Variant = entity_query.call("get_entity_id")
		context["camera_entity_id"] = camera_entity_id
		context["entity_id"] = camera_entity_id
	if entity_query.has_method("get_tags"):
		var camera_tags: Variant = entity_query.call("get_tags")
		context["camera_entity_tags"] = camera_tags
		context["entity_tags"] = camera_tags

	if "entity" in entity_query:
		var camera_entity: Variant = entity_query.get("entity")
		if camera_entity != null:
			context["camera_entity"] = camera_entity
			context["entity"] = camera_entity

func _apply_camera_state(contexts: Array, delta: float) -> void:
	var manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	if manager == null:
		return

	var context: Dictionary = _select_primary_camera_context(contexts)
	var primary_camera_state: Variant = context.get("camera_state_component", null)
	_decay_non_primary_trauma(contexts, primary_camera_state, delta)
	if context.is_empty():
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	if primary_camera_state == null or not (primary_camera_state is Object):
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	var main_camera: Camera3D = manager.get_main_camera()
	if main_camera != null:
		_apply_fov_to_camera(main_camera, primary_camera_state, context, delta)

	_apply_trauma_shake(manager, primary_camera_state, delta)

func _decay_non_primary_trauma(contexts: Array, primary_camera_state: Variant, delta: float) -> void:
	if delta <= 0.0:
		return

	var processed_states: Dictionary = {}
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant as Dictionary
		var camera_state: Variant = context.get("camera_state_component", null)
		if camera_state == null or not (camera_state is Object):
			continue
		if primary_camera_state != null and camera_state == primary_camera_state:
			continue

		var camera_state_object: Object = camera_state as Object
		var state_id: int = camera_state_object.get_instance_id()
		if processed_states.has(state_id):
			continue
		processed_states[state_id] = true
		_decay_trauma(camera_state_object, delta)

func _select_primary_camera_context(contexts: Array) -> Dictionary:
	var fallback: Dictionary = {}
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant as Dictionary
		if fallback.is_empty():
			fallback = context
		if _is_primary_camera_context(context):
			return context
	return fallback

func _is_primary_camera_context(context: Dictionary) -> bool:
	var id_variant: Variant = U_RuleUtils.get_context_value(context, "camera_entity_id")
	if id_variant == null:
		id_variant = U_RuleUtils.get_context_value(context, "entity_id")
	var entity_id: StringName = U_RuleUtils.variant_to_string_name(id_variant)
	if entity_id == PRIMARY_CAMERA_ENTITY_ID:
		return true

	var tags_variant: Variant = U_RuleUtils.get_context_value(context, "camera_entity_tags")
	if tags_variant == null:
		tags_variant = U_RuleUtils.get_context_value(context, "entity_tags")
	if tags_variant is Array:
		var tags: Array = tags_variant as Array
		return tags.has(PRIMARY_CAMERA_ENTITY_ID) or tags.has(String(PRIMARY_CAMERA_ENTITY_ID))
	return false

func _apply_fov_to_camera(camera: Camera3D, camera_state: Variant, context: Dictionary, delta: float) -> void:
	var baseline_fov: float = _ensure_baseline_fov(camera_state, camera.fov)
	var target_fov: float = _resolve_target_fov(camera_state, context, baseline_fov)
	_write_target_fov(camera_state, target_fov)

	var blend_speed: float = maxf(
		_get_camera_state_float(camera_state, "fov_blend_speed", C_CAMERA_STATE_COMPONENT.DEFAULT_FOV_BLEND_SPEED),
		0.0
	)
	if blend_speed <= 0.0:
		camera.fov = target_fov
		return

	var alpha: float = clampf(blend_speed * maxf(delta, 0.0), 0.0, 1.0)
	if alpha <= 0.0:
		return
	camera.fov = lerpf(camera.fov, target_fov, alpha)

func _resolve_target_fov(camera_state: Variant, context: Dictionary, baseline_fov: float) -> float:
	var base_target_fov: float = baseline_fov
	if _is_fov_zone_active(context):
		base_target_fov = _get_camera_state_float(
			camera_state,
			"target_fov",
			C_CAMERA_STATE_COMPONENT.DEFAULT_TARGET_FOV
		)
	var resolved_base_target_fov: float = clampf(base_target_fov, 1.0, 179.0)
	var speed_fov_bonus: float = _resolve_speed_fov_bonus(camera_state)
	return clampf(resolved_base_target_fov + speed_fov_bonus, 1.0, 179.0)

func _ensure_baseline_fov(camera_state: Variant, fallback_fov: float) -> float:
	var existing_baseline: float = _get_camera_state_float(
		camera_state,
		"base_fov",
		C_CAMERA_STATE_COMPONENT.UNSET_BASE_FOV
	)
	if existing_baseline > 1.0:
		return clampf(existing_baseline, 1.0, 179.0)

	var resolved_baseline: float = clampf(fallback_fov, 1.0, 179.0)
	_write_baseline_fov(camera_state, resolved_baseline)
	return resolved_baseline

func _is_fov_zone_active(context: Dictionary) -> bool:
	var state_variant: Variant = U_RuleUtils.get_context_value(context, "state")
	if state_variant == null:
		state_variant = U_RuleUtils.get_context_value(context, "redux_state")
	if not (state_variant is Dictionary):
		return false
	return U_VCAM_SELECTORS.is_in_fov_zone(state_variant as Dictionary)

func _write_target_fov(camera_state: Variant, value: float) -> void:
	if camera_state is Object and (camera_state as Object).has_method("set_target_fov"):
		(camera_state as Object).call("set_target_fov", value)
		return
	if camera_state is Object:
		(camera_state as Object).set("target_fov", clampf(value, 1.0, 179.0))

func _write_baseline_fov(camera_state: Variant, value: float) -> void:
	var clamped: float = clampf(value, 1.0, 179.0)
	if camera_state is Object and (camera_state as Object).has_method("set_base_fov"):
		(camera_state as Object).call("set_base_fov", clamped)
		return
	if camera_state is Object:
		(camera_state as Object).set("base_fov", clamped)

func _resolve_speed_fov_bonus(camera_state: Variant) -> float:
	var raw_bonus: float = _get_camera_state_float(
		camera_state,
		"speed_fov_bonus",
		C_CAMERA_STATE_COMPONENT.DEFAULT_SPEED_FOV_BONUS
	)
	var max_bonus: float = maxf(
		_get_camera_state_float(
			camera_state,
			"speed_fov_max_bonus",
			C_CAMERA_STATE_COMPONENT.DEFAULT_SPEED_FOV_MAX_BONUS
		),
		0.0
	)
	var clamped_bonus: float = clampf(raw_bonus, 0.0, max_bonus)
	if not is_equal_approx(clamped_bonus, raw_bonus):
		_write_speed_fov_bonus(camera_state, clamped_bonus)
	return clamped_bonus

func _write_speed_fov_bonus(camera_state: Variant, value: float) -> void:
	if camera_state == null or not (camera_state is Object):
		return
	var object_value: Object = camera_state as Object
	if not U_RuleUtils.object_has_property(object_value, "speed_fov_bonus"):
		return
	object_value.set("speed_fov_bonus", maxf(value, 0.0))

func _apply_trauma_shake(manager: I_CAMERA_MANAGER, camera_state: Variant, delta: float) -> void:
	var trauma: float = clampf(_get_camera_state_float(camera_state, "shake_trauma", 0.0), 0.0, 1.0)
	if trauma <= 0.0:
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		_write_shake_trauma(camera_state, 0.0)
		return

	_shake_time += maxf(delta, 0.0)
	var shake_strength: float = trauma * trauma
	var offset: Vector2 = Vector2(
		sin(_shake_time * SHAKE_FREQ_OFFSET_X + SHAKE_PHASE_OFFSET_X),
		cos(_shake_time * SHAKE_FREQ_OFFSET_Y + SHAKE_PHASE_OFFSET_Y)
	) * SHAKE_MAX_OFFSET_PX * shake_strength
	var rotation: float = sin(_shake_time * SHAKE_FREQ_ROTATION + SHAKE_PHASE_ROTATION) * SHAKE_MAX_ROTATION_RAD * shake_strength
	manager.set_shake_source(CAMERA_SHAKE_SOURCE, offset, rotation)

	var decayed_trauma: float = _decay_trauma(camera_state, delta)
	if decayed_trauma <= 0.0:
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)

func _decay_trauma(camera_state: Variant, delta: float) -> float:
	var trauma: float = clampf(_get_camera_state_float(camera_state, "shake_trauma", 0.0), 0.0, 1.0)
	if delta <= 0.0:
		return trauma

	var decayed_trauma: float = maxf(trauma - SHAKE_TRAUMA_DECAY_RATE * delta, 0.0)
	_write_shake_trauma(camera_state, decayed_trauma)
	return decayed_trauma

func _write_shake_trauma(camera_state: Variant, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if camera_state is Object and (camera_state as Object).has_method("set_shake_trauma"):
		(camera_state as Object).call("set_shake_trauma", clamped)
		return
	if camera_state is Object:
		(camera_state as Object).set("shake_trauma", clamped)

func _get_camera_state_float(camera_state: Variant, property_name: String, fallback: float) -> float:
	if camera_state == null or not (camera_state is Object):
		return fallback
	var object_value: Object = camera_state as Object
	if not U_RuleUtils.object_has_property(object_value, property_name):
		return fallback
	return U_RuleUtils.read_float_property(object_value, property_name, fallback)

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	if camera_manager != null:
		return camera_manager
	if _camera_manager != null and is_instance_valid(_camera_manager):
		return _camera_manager

	var service: Variant = U_SERVICE_LOCATOR.try_get_service(CAMERA_MANAGER_SERVICE)
	if service is I_CAMERA_MANAGER:
		_camera_manager = service as I_CAMERA_MANAGER
		return _camera_manager
	return null

func _resolve_store() -> I_StateStore:
	if state_store != null:
		return state_store
	return U_STATE_UTILS.try_get_store(self)

func _get_frame_state_snapshot() -> Dictionary:
	var manager := get_manager()
	if manager != null and manager.has_method("get_frame_state_snapshot"):
		return manager.get_frame_state_snapshot()
	var store: I_StateStore = _resolve_store()
	if store != null:
		return store.get_state()
	return {}

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
