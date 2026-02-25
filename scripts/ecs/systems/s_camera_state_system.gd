@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_CameraStateSystem

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const U_RULE_SCORER := preload("res://scripts/utils/qb/u_rule_scorer.gd")
const U_RULE_SELECTOR := preload("res://scripts/utils/qb/u_rule_selector.gd")
const RULE_STATE_TRACKER := preload("res://scripts/utils/qb/u_rule_state_tracker.gd")
const U_RULE_VALIDATOR := preload("res://scripts/utils/qb/u_rule_validator.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const CAMERA_MANAGER_SERVICE := StringName("camera_manager")
const CAMERA_SHAKE_SOURCE := StringName("qb_camera_rule")
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")

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
]

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var rules: Array[Resource] = []

var _camera_manager: I_CAMERA_MANAGER = null
var _tracker: RuleStateTracker = RULE_STATE_TRACKER.new()
var _active_rules: Array = []
var _rule_validation_report: Dictionary = {}
var _event_unsubscribers: Array[Callable] = []
var _has_tick_rules: bool = false
var _shake_time: float = 0.0

func on_configured() -> void:
	_refresh_active_rules()
	_subscribe_rule_events()
	_camera_manager = _resolve_camera_manager()

func _exit_tree() -> void:
	_unsubscribe_rule_events()

func process_tick(delta: float) -> void:
	_tracker.tick_cooldowns(delta)

	var contexts: Array = _build_camera_contexts({})
	if contexts.is_empty():
		var manager_when_empty: I_CAMERA_MANAGER = _resolve_camera_manager()
		if manager_when_empty != null:
			manager_when_empty.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	var active_context_keys: Array = []
	if _has_tick_rules:
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

	_tracker.cleanup_stale_contexts(active_context_keys)
	_apply_camera_state(contexts, delta)

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

		var event_name: StringName = _read_string_name_property(rule_variant, "trigger_event")
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

	_tracker.cleanup_stale_contexts(active_context_keys)
	_apply_camera_state(contexts, 0.0)

func _evaluate_context(context: Dictionary, trigger_mode: String, event_name: StringName) -> void:
	var applicable_rules: Array = _get_applicable_rules(trigger_mode, event_name)
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

func _get_applicable_rules(trigger_mode: String, event_name: StringName) -> Array:
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
			if _read_string_name_property(rule_variant, "trigger_event") == event_name:
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
			if not effect_variant.has_method("execute"):
				continue
			effect_variant.call("execute", context)

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

func _context_key_for_context(context: Dictionary) -> StringName:
	var camera_entity_id: StringName = _variant_to_string_name(_get_context_value(context, "camera_entity_id"))
	if camera_entity_id != StringName():
		return camera_entity_id

	var entity_id: StringName = _variant_to_string_name(_get_context_value(context, "entity_id"))
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

func _build_camera_contexts(base_context: Dictionary) -> Array:
	var contexts: Array = []
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = {}
	if store != null:
		redux_state = store.get_state()

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
		_attach_camera_context(context, entity_query, camera_state, redux_state, store)
		contexts.append(context)

	return contexts

func _attach_camera_context(
	context: Dictionary,
	entity_query: Object,
	camera_state: Variant,
	redux_state: Dictionary,
	store: I_StateStore
) -> void:
	context["camera_state_component"] = camera_state

	var components: Dictionary = {}
	components[CAMERA_STATE_TYPE] = camera_state
	components[String(CAMERA_STATE_TYPE)] = camera_state
	context["components"] = components
	context["component_data"] = components

	context["redux_state"] = redux_state.duplicate(true)
	context["state"] = context["redux_state"]
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
	var id_variant: Variant = _get_context_value(context, "camera_entity_id")
	if id_variant == null:
		id_variant = _get_context_value(context, "entity_id")
	var entity_id: StringName = _variant_to_string_name(id_variant)
	if entity_id == PRIMARY_CAMERA_ENTITY_ID:
		return true

	var tags_variant: Variant = _get_context_value(context, "camera_entity_tags")
	if tags_variant == null:
		tags_variant = _get_context_value(context, "entity_tags")
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
	if not _is_fov_zone_active(context):
		return baseline_fov
	var target_fov: float = _get_camera_state_float(
		camera_state,
		"target_fov",
		C_CAMERA_STATE_COMPONENT.DEFAULT_TARGET_FOV
	)
	return clampf(target_fov, 1.0, 179.0)

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
	var state_variant: Variant = _get_context_value(context, "state")
	if state_variant == null:
		state_variant = _get_context_value(context, "redux_state")
	if not (state_variant is Dictionary):
		return false
	var state: Dictionary = state_variant as Dictionary

	var camera_slice_variant: Variant = _get_context_value(state, "camera")
	if not (camera_slice_variant is Dictionary):
		return false
	var camera_slice: Dictionary = camera_slice_variant as Dictionary

	var in_zone_variant: Variant = _get_context_value(camera_slice, "in_fov_zone")
	if in_zone_variant is bool:
		return in_zone_variant
	return false

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
	if not _object_has_property(object_value, property_name):
		return fallback
	return _get_float_property(object_value, property_name, fallback)

func _object_has_property(object_value: Object, property_name: String) -> bool:
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_value: Variant = property_info.get("name", "")
		if str(name_value) == property_name:
			return true
	return false

func _get_float_property(object_value: Object, property_name: String, fallback: float) -> float:
	if not _object_has_property(object_value, property_name):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

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

func _extract_event_payload(event_data: Dictionary) -> Dictionary:
	var payload_variant: Variant = event_data.get("payload", null)
	if payload_variant is Dictionary:
		return (payload_variant as Dictionary).duplicate(true)
	if event_data is Dictionary:
		return event_data.duplicate(true)
	return {}

func _get_context_value(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null

func _variant_to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	if value is String:
		var text: String = value
		if text.is_empty():
			return StringName()
		return StringName(text)
	return StringName()

func _read_string_property(object_value: Variant, property_name: String, fallback: String) -> String:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = (object_value as Object).get(property_name)
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

func _read_string_name_property(object_value: Variant, property_name: String) -> StringName:
	if object_value == null or not (object_value is Object):
		return StringName()
	var value: Variant = (object_value as Object).get(property_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName()

func _read_float_property(object_value: Variant, property_name: String, fallback: float) -> float:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = (object_value as Object).get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _read_bool_property(object_value: Variant, property_name: String, fallback: bool) -> bool:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = (object_value as Object).get(property_name)
	if value is bool:
		return value
	return fallback
