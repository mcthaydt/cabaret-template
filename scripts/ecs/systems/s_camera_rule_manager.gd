@icon("res://assets/editor_icons/icn_system.svg")
extends BaseQBRuleManager
class_name S_CameraRuleManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const CAMERA_MANAGER_SERVICE := StringName("camera_manager")
const CAMERA_SHAKE_SOURCE := StringName("qb_camera_rule")
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")
const SHAKE_TRAUMA_DECAY_RATE: float = 2.0
const SHAKE_MAX_OFFSET_PX: float = 10.0
const SHAKE_MAX_ROTATION_RAD: float = 0.03
const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/camera/cfg_camera_shake_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_zone_fov_rule.tres"),
]

@export var camera_manager: I_CAMERA_MANAGER = null

var _camera_manager: I_CAMERA_MANAGER = null
var _shake_time: float = 0.0

func on_configured() -> void:
	super.on_configured()
	_camera_manager = _resolve_camera_manager()

func get_default_rule_definitions() -> Array:
	return DEFAULT_RULE_DEFINITIONS.duplicate()

func process_tick(delta: float) -> void:
	_tick_cooldowns(delta)
	_begin_tick_context_tracking()
	var contexts: Array = _get_tick_contexts(delta)
	_evaluate_contexts(contexts, QB_RULE.TriggerMode.TICK)
	_cleanup_stale_context_state()
	_apply_camera_state(contexts, delta)

func _get_tick_contexts(_delta: float) -> Array:
	return _build_camera_contexts({})

func _on_event_received(event_name: StringName, event_data: Dictionary) -> void:
	var payload: Dictionary = {}
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		payload = (event_data["payload"] as Dictionary).duplicate(true)
	elif event_data is Dictionary:
		payload = event_data.duplicate(true)

	var event_context: Dictionary = _build_event_context(event_name, payload)
	var contexts: Array = _build_camera_contexts(event_context)
	if contexts.is_empty():
		_ensure_context_dependencies(event_context)
		_evaluate_rules_for_context(event_context, QB_RULE.TriggerMode.EVENT, event_name)
		return

	_evaluate_contexts(contexts, QB_RULE.TriggerMode.EVENT, event_name)
	_apply_camera_state(contexts, 0.0)

func _build_camera_contexts(base_context: Dictionary) -> Array:
	var contexts: Array = []
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = {}
	if store != null:
		redux_state = store.get_state()

	var entities: Array = query_entities([CAMERA_STATE_TYPE])
	for entity_query_variant in entities:
		var entity_query: Object = entity_query_variant as Object
		if entity_query == null:
			continue
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
	var camera_state_type_key: String = String(CAMERA_STATE_TYPE)
	if not components.has(camera_state_type_key):
		components[camera_state_type_key] = camera_state
	context["components"] = components
	context["component_data"] = components
	context["redux_state"] = redux_state.duplicate(true)
	context["state"] = context["redux_state"]
	if store != null:
		context["state_store"] = store

	if entity_query.has_method("get_entity_id"):
		var camera_entity_id: Variant = entity_query.call("get_entity_id")
		context["camera_entity_id"] = camera_entity_id
		if not context.has("entity_id"):
			context["entity_id"] = camera_entity_id
	if entity_query.has_method("get_tags"):
		var camera_tags: Variant = entity_query.call("get_tags")
		context["camera_entity_tags"] = camera_tags
		if not context.has("entity_tags"):
			context["entity_tags"] = camera_tags

	var camera_entity: Variant = entity_query.get("entity")
	if camera_entity != null:
		context["camera_entity"] = camera_entity
		if not context.has("entity"):
			context["entity"] = camera_entity

func _resolve_store() -> I_StateStore:
	if state_store != null:
		return state_store
	return U_STATE_UTILS.try_get_store(self)

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

func _apply_camera_state(contexts: Array, delta: float) -> void:
	var manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	if manager == null:
		return

	var context: Dictionary = _select_primary_camera_context(contexts)
	if context.is_empty():
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	var camera_state: Variant = context.get("camera_state_component", null)
	if camera_state == null or not (camera_state is Object):
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	var main_camera: Camera3D = manager.get_main_camera()
	if main_camera != null:
		_apply_fov_to_camera(main_camera, camera_state, context, delta)

	_apply_trauma_shake(manager, camera_state, delta)

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
	var id_variant: Variant = context.get("camera_entity_id", context.get("entity_id", &""))
	if id_variant is StringName:
		return id_variant == PRIMARY_CAMERA_ENTITY_ID
	if id_variant is String:
		return StringName(id_variant) == PRIMARY_CAMERA_ENTITY_ID

	var tags_variant: Variant = context.get("camera_entity_tags", context.get("entity_tags", []))
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
	var state_variant: Variant = context.get("state", context.get("redux_state", {}))
	if not (state_variant is Dictionary):
		return false
	var state: Dictionary = state_variant as Dictionary
	var camera_slice_variant: Variant = state.get("camera", {})
	if not (camera_slice_variant is Dictionary):
		return false
	var camera_slice: Dictionary = camera_slice_variant as Dictionary
	return bool(camera_slice.get("in_fov_zone", false))

func _write_target_fov(camera_state: Variant, value: float) -> void:
	if camera_state.has_method("set_target_fov"):
		camera_state.call("set_target_fov", value)
		return
	camera_state.set("target_fov", clampf(value, 1.0, 179.0))

func _write_baseline_fov(camera_state: Variant, value: float) -> void:
	var clamped: float = clampf(value, 1.0, 179.0)
	if camera_state.has_method("set_base_fov"):
		camera_state.call("set_base_fov", clamped)
		return
	camera_state.set("base_fov", clamped)

func _apply_trauma_shake(manager: I_CAMERA_MANAGER, camera_state: Variant, delta: float) -> void:
	var trauma: float = clampf(_get_camera_state_float(camera_state, "shake_trauma", 0.0), 0.0, 1.0)
	if trauma <= 0.0:
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		_write_shake_trauma(camera_state, 0.0)
		return

	_shake_time += maxf(delta, 0.0)
	var shake_strength: float = trauma * trauma
	var offset: Vector2 = Vector2(
		sin(_shake_time * 17.0 + 1.1),
		cos(_shake_time * 21.0 + 2.3)
	) * SHAKE_MAX_OFFSET_PX * shake_strength
	var rotation: float = sin(_shake_time * 13.0 + 0.7) * SHAKE_MAX_ROTATION_RAD * shake_strength
	manager.set_shake_source(CAMERA_SHAKE_SOURCE, offset, rotation)

	if delta <= 0.0:
		return
	var decayed_trauma: float = maxf(trauma - SHAKE_TRAUMA_DECAY_RATE * delta, 0.0)
	_write_shake_trauma(camera_state, decayed_trauma)
	if decayed_trauma <= 0.0:
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)

func _write_shake_trauma(camera_state: Variant, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if camera_state.has_method("set_shake_trauma"):
		camera_state.call("set_shake_trauma", clamped)
		return
	camera_state.set("shake_trauma", clamped)

func _get_camera_state_float(camera_state: Variant, property_name: String, fallback: float) -> float:
	if camera_state == null or not (camera_state is Object):
		return fallback
	var object_value: Object = camera_state as Object
	if not _object_has_property(object_value, property_name):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _object_has_property(object_value: Object, property_name: String) -> bool:
	var properties: Array = object_value.get_property_list()
	for property_info_variant in properties:
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant as Dictionary
		var name_variant: Variant = property_info.get("name", "")
		if String(name_variant) == property_name:
			return true
	return false
